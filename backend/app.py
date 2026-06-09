from flask import Flask, render_template, request, jsonify, send_file
from flask_cors import CORS
from io import BytesIO
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
import joblib
import json
import sqlite3
import datetime
from database import init_db, DB_NAME
import pandas as pd

app = Flask(__name__)
# Allow all origins so Flutter emulator (10.0.2.2) and web can call us
CORS(app)

# Initialize database
init_db()

# Load model and feature names
try:
    model = joblib.load('models/rf_model.pkl')
    feature_names = joblib.load('models/feature_names.pkl')
    with open('data/precautions.json', 'r') as f:
        precautions_dict = json.load(f)
except Exception as e:
    print(f"Error loading models or data: {e}")
    print("Please run `python train_model.py` first.")
    model = None
    feature_names = []
    precautions_dict = {}

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/history')
def history():
    return render_template('history.html')

@app.route('/reminders')
def reminders():
    return render_template('reminders.html')


@app.route('/api/symptoms', methods=['GET'])
def get_symptoms():
    return jsonify(feature_names)

@app.route('/api/predict', methods=['POST'])
def predict():
    if not model:
        return jsonify({'error': 'Model not loaded. Train the model first.'}), 500

    data = request.json or {}
    selected_symptoms = data.get('symptoms', [])

    if not selected_symptoms:
        return jsonify({'error': 'No symptoms provided.'}), 400

    # Parse patient details with sensible defaults
    age = int(data.get('age', 30))
    sex = data.get('sex', 'Male')
    smoker = data.get('smoker', 'No')
    weight = float(data.get('weight', 70.0))
    height = float(data.get('height', 170.0))
    existing_conditions = data.get('existing_conditions', [])
    duration = data.get('duration', '1-3 days')
    severity = data.get('severity', 'Moderate')

    # Create a feature vector initialized with zeros
    input_vector = {feature: 0 for feature in feature_names}
    
    # Set selected symptoms to 1
    for symptom in selected_symptoms:
        if symptom in input_vector:
            input_vector[symptom] = 1
            
    # Convert to DataFrame to match training data
    input_df = pd.DataFrame([input_vector])
    
    # Predict base probabilities
    # Predict base probabilities
    probabilities = model.predict_proba(input_df)[0]
    classes = model.classes_
    
    # Calculate BMI
    bmi = 22.0
    if height > 0:
        bmi = weight / ((height / 100) ** 2)
    
    # Map probability to dictionary for adjustment with a small smoothing epsilon
    epsilon = 0.05
    prob_dict = {classes[i]: float(probabilities[i]) + epsilon for i in range(len(classes))}
    
    # Define clinical risk factor modifiers based on patient details
    for disease in prob_dict:
        multiplier = 1.0
        
        # 1. Common Cold scaling (more common in children, rare in elderly, low duration/severity)
        if disease == 'Common Cold':
            if age < 12:
                multiplier *= 1.3
            elif age >= 60:
                multiplier *= 0.8
            if duration in ['1-2 weeks', 'More than 2 weeks']:
                multiplier *= 0.3
            if severity == 'Severe':
                multiplier *= 0.4
                
        # 2. Influenza scaling (high risk for elderly, infants, and pregnant females)
        elif disease == 'Influenza':
            if age >= 65 or age < 5:
                multiplier *= 1.5
            if severity == 'Severe':
                multiplier *= 1.3
            # Childbearing age females have higher complication risks
            if sex == 'Female' and age >= 18 and age <= 45:
                multiplier *= 1.2
                
        # 3. COVID-19 scaling (high risk for elderly, smokers, and obese)
        elif disease == 'COVID-19':
            if age >= 60:
                multiplier *= 1.5
            elif age < 18:
                multiplier *= 0.6
            if smoker == 'Yes':
                multiplier *= 1.3
            if bmi >= 30:
                multiplier *= 1.3
                
        # 4. Malaria scaling (high risk for children under 5 and pregnant females)
        elif disease == 'Malaria':
            if age < 5:
                multiplier *= 1.4
            if sex == 'Female' and age >= 18 and age <= 40:
                multiplier *= 1.2
                
        # 5. Dengue scaling (more common/severe in younger adults)
        elif disease == 'Dengue':
            if age < 25:
                multiplier *= 1.3
            elif age >= 60:
                multiplier *= 0.8
                
        # 6. Typhoid scaling (high risk for children/young adults)
        elif disease == 'Typhoid':
            if age < 20:
                multiplier *= 1.4
            elif age >= 60:
                multiplier *= 0.7
                
        # 7. Allergy scaling (triggered/aggravated by history and high duration)
        elif disease == 'Allergy':
            if any(c.lower() in ['allergies', 'asthma'] for c in existing_conditions):
                multiplier *= 2.0
            if duration in ['1-2 weeks', 'More than 2 weeks']:
                multiplier *= 1.5
            if severity == 'Severe':
                multiplier *= 0.6
                
        # 8. Bronchitis scaling (extremely smoking and age dependent)
        elif disease == 'Bronchitis':
            if smoker == 'Yes':
                multiplier *= 2.0
            if age >= 50:
                multiplier *= 1.4
            elif age < 25:
                multiplier *= 0.6
            if any(c.lower() in ['asthma', 'copd', 'diabetes'] for c in existing_conditions):
                multiplier *= 1.3
            if severity == 'Severe':
                multiplier *= 1.3
            if duration in ['4-7 days', '1-2 weeks', 'More than 2 weeks']:
                multiplier *= 1.2
                
        # 9. Pneumonia scaling (high risk for elderly, smokers, asthma/COPD history)
        elif disease == 'Pneumonia':
            if age >= 65:
                multiplier *= 1.8
            elif age < 5:
                multiplier *= 1.4
            elif age < 30:
                multiplier *= 0.8
            if smoker == 'Yes':
                multiplier *= 1.6
            if any(c.lower() in ['asthma', 'copd', 'diabetes'] for c in existing_conditions):
                multiplier *= 1.3
            if severity == 'Severe':
                multiplier *= 1.3
            if duration in ['4-7 days', '1-2 weeks', 'More than 2 weeks']:
                multiplier *= 1.2
                
        # 10. Heart Attack / Angina scaling (highly age, gender, smoker, and obesity dependent)
        elif disease == 'Heart Attack / Angina':
            if age >= 55:
                multiplier *= 2.5
            elif age >= 40:
                multiplier *= 1.5
            elif age < 30:
                multiplier *= 0.05
            
            if smoker == 'Yes':
                multiplier *= 1.8
            if any(c.lower() in ['hypertension', 'diabetes', 'heart disease'] for c in existing_conditions):
                multiplier *= 1.6
            if severity == 'Severe':
                multiplier *= 1.5
                
            # Gender modifiers
            if sex == 'Male':
                multiplier *= 1.4
            elif sex == 'Female':
                if age < 50:
                    multiplier *= 0.7
                else:
                    multiplier *= 1.1
            
            # Obesity/BMI modifiers
            if bmi >= 30:
                multiplier *= 1.6
            elif bmi >= 25:
                multiplier *= 1.2
                
        # 11. GERD scaling (highly obesity and age dependent)
        elif disease == 'GERD':
            if age >= 40:
                multiplier *= 1.3
            if duration in ['1-2 weeks', 'More than 2 weeks']:
                multiplier *= 1.3
            if severity == 'Severe':
                multiplier *= 0.7
            if bmi >= 25:
                multiplier *= 1.5
                
        # 12. Asthma Exacerbation scaling (strongly medical history dependent)
        elif disease == 'Asthma Exacerbation':
            if any('asthma' in c.lower() for c in existing_conditions):
                multiplier *= 3.0
            else:
                multiplier *= 0.1
            if smoker == 'Yes':
                multiplier *= 1.4
                
        # 13. Migraine scaling
        elif disease == 'Migraine':
            if sex == 'Female':
                multiplier *= 1.4
                
        # 14. Gastroenteritis scaling
        elif disease == 'Gastroenteritis':
            if age < 10:
                multiplier *= 1.3
                
        # 15. Tuberculosis scaling
        elif disease == 'Tuberculosis':
            if smoker == 'Yes':
                multiplier *= 1.5
            if age >= 60:
                multiplier *= 1.3
                
        # 16. UTI scaling
        elif disease == 'Urinary Tract Infection (UTI)':
            if sex == 'Female':
                multiplier *= 2.0
                
        prob_dict[disease] *= multiplier
        
    # Re-normalize modified probabilities so they sum to 1.0
    total_score = sum(prob_dict.values())
    if total_score > 0:
        for disease in prob_dict:
            prob_dict[disease] = prob_dict[disease] / total_score
    else:
        # Fallback to standard ML probability if all factors are zero
        prob_dict = {classes[i]: float(probabilities[i]) for i in range(len(classes))}
        
    # Get top 3 predictions from the personalized distribution
    sorted_predictions = sorted(prob_dict.items(), key=lambda item: item[1], reverse=True)
    
    top_predictions = [
        {
            'disease': d,
            'confidence': round(float(conf) * 100, 2)
        }
        for d, conf in sorted_predictions[:3] if conf > 0
    ]
    
    # Primary prediction
    predicted_disease = top_predictions[0]['disease']
    confidence = top_predictions[0]['confidence']
    
    # Get precautions
    precautions = precautions_dict.get(predicted_disease, ["Consult a doctor for further advice."])
    
    # Dynamic specialist recommendations
    recommendation_map = {
        'Pneumonia': 'Consult a Pulmonologist.',
        'Bronchitis': 'Consult a Pulmonologist.',
        'Asthma Exacerbation': 'Consult a Pulmonologist or Allergist.',
        'Heart Attack / Angina': 'Consult a Cardiologist immediately (EMERGENCY: Call 911 if experiencing chest pain and shortness of breath!).',
        'GERD': 'Consult a Gastroenterologist.',
        'Allergy': 'Consult an Allergist.',
        'Common Cold': 'Consult a General Physician.',
        'Influenza': 'Consult a General Physician.',
        'Malaria': 'Consult an Infectious Disease Specialist.',
        'Dengue': 'Consult an Infectious Disease Specialist.',
        'Typhoid': 'Consult an Infectious Disease Specialist or General Physician.',
        'COVID-19': 'Consult a General Physician (Isolate and monitor oxygen levels).',
        'Migraine': 'Consult a Neurologist.',
        'Gastroenteritis': 'Consult a Gastroenterologist or General Physician.',
        'Tuberculosis': 'Consult a Pulmonologist or Infectious Disease Specialist.',
        'Urinary Tract Infection (UTI)': 'Consult a Urologist or General Physician.'
    }
    recommendation = recommendation_map.get(predicted_disease, 'Consult a General Physician.')
    
    # Save to history
    inserted_id = None
    try:
        conn = sqlite3.connect(DB_NAME)
        cursor = conn.cursor()
        cursor.execute('''
        INSERT INTO predictions (
            symptoms, predicted_disease, confidence, precautions,
            age, sex, smoker, weight, height, existing_conditions, duration, severity, recommendation
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            json.dumps(selected_symptoms),
            predicted_disease,
            confidence,
            json.dumps(precautions),
            age,
            sex,
            smoker,
            weight,
            height,
            json.dumps(existing_conditions),
            duration,
            severity,
            recommendation
        ))
        inserted_id = cursor.lastrowid
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"Failed to save history: {e}")

    return jsonify({
        'id': inserted_id,
        'disease': predicted_disease,
        'confidence': confidence,
        'precautions': precautions,
        'top_predictions': top_predictions,
        'age': age,
        'sex': sex,
        'smoker': smoker,
        'weight': weight,
        'height': height,
        'existing_conditions': existing_conditions,
        'duration': duration,
        'severity': severity,
        'recommendation': recommendation
    })

@app.route('/api/history', methods=['GET'])
def get_history():
    try:
        conn = sqlite3.connect(DB_NAME)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM predictions ORDER BY timestamp DESC LIMIT 50')
        rows = cursor.fetchall()
        conn.close()
        
        history_list = []
        for row in rows:
            history_list.append({
                'id': row['id'],
                'timestamp': row['timestamp'],
                'symptoms': json.loads(row['symptoms']),
                'predicted_disease': row['predicted_disease'],
                'confidence': row['confidence'],
                'precautions': json.loads(row['precautions']),
                'age': row['age'] if 'age' in row.keys() else None,
                'sex': row['sex'] if 'sex' in row.keys() else None,
                'smoker': row['smoker'] if 'smoker' in row.keys() else None,
                'weight': row['weight'] if 'weight' in row.keys() else None,
                'height': row['height'] if 'height' in row.keys() else None,
                'existing_conditions': json.loads(row['existing_conditions']) if 'existing_conditions' in row.keys() and row['existing_conditions'] else [],
                'duration': row['duration'] if 'duration' in row.keys() else None,
                'severity': row['severity'] if 'severity' in row.keys() else None,
                'recommendation': row['recommendation'] if 'recommendation' in row.keys() else None
            })
            
        return jsonify(history_list)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/history/<int:record_id>', methods=['DELETE'])
def delete_history(record_id):
    try:
        conn = sqlite3.connect(DB_NAME)
        cursor = conn.cursor()
        cursor.execute('DELETE FROM predictions WHERE id = ?', (record_id,))
        conn.commit()
        conn.close()
        return jsonify({'success': True, 'message': f'Record {record_id} deleted.'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def generate_medical_report_pdf(record):
    buffer = BytesIO()
    
    # Page setup - 0.75 inch margins
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )
    
    styles = getSampleStyleSheet()
    
    # Custom styles
    primary_color = colors.HexColor('#0E627A')
    secondary_color = colors.HexColor('#2C3E50')
    accent_color = colors.HexColor('#E67E22')
    light_bg = colors.HexColor('#F8F9FA')
    
    title_style = ParagraphStyle(
        'ReportTitle',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=18,
        textColor=colors.white,
        alignment=1, # Center
        spaceAfter=0
    )
    
    subtitle_style = ParagraphStyle(
        'ReportSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=10,
        textColor=colors.HexColor('#D1ECF1'),
        alignment=1,
        spaceAfter=0
    )
    
    section_heading = ParagraphStyle(
        'SectionHeading',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=12,
        textColor=primary_color,
        spaceBefore=14,
        spaceAfter=8,
        keepWithNext=True
    )
    
    body_style = ParagraphStyle(
        'ReportBody',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        textColor=secondary_color,
        leading=14
    )
    
    bold_body_style = ParagraphStyle(
        'ReportBodyBold',
        parent=body_style,
        fontName='Helvetica-Bold'
    )
    
    disclaimer_style = ParagraphStyle(
        'DisclaimerText',
        parent=styles['Normal'],
        fontName='Helvetica-Oblique',
        fontSize=8,
        textColor=colors.HexColor('#7F8C8D'),
        leading=11
    )

    story = []
    
    # 1. Header block (Teal background)
    header_data = [
        [Paragraph("AI HEALTH SYMPTOM CHECKER", title_style)],
        [Paragraph("OFFICIAL ASSESSMENT & MEDICAL REPORT", subtitle_style)]
    ]
    header_table = Table(header_data, colWidths=[doc.width])
    header_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), primary_color),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 14),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 14),
        ('LEFTPADDING', (0, 0), (-1, -1), 20),
        ('RIGHTPADDING', (0, 0), (-1, -1), 20),
    ]))
    story.append(header_table)
    story.append(Spacer(1, 15))
    
    # 2. Metadata / Patient Details (Two columns)
    record_id = record['id']
    timestamp = record['timestamp']
    try:
        dt = datetime.datetime.strptime(timestamp.split('.')[0], "%Y-%m-%d %H:%M:%S")
        date_str = dt.strftime("%B %d, %Y • %I:%M %p")
    except:
        date_str = timestamp
        
    meta_data = [
        [Paragraph("<b>Report ID:</b> AHC-{:06d}".format(record_id), body_style), 
         Paragraph("<b>Date Generated:</b> {}".format(date_str), body_style)],
        [Paragraph("<b>Assessed By:</b> AI Health Checker Engine", body_style), 
         Paragraph("<b>Status:</b> Completed", body_style)]
    ]
    meta_table = Table(meta_data, colWidths=[doc.width/2.0, doc.width/2.0])
    meta_table.setStyle(TableStyle([
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('LINEBELOW', (0, 1), (-1, 1), 0.5, colors.HexColor('#BDC3C7')),
    ]))
    story.append(meta_table)
    story.append(Spacer(1, 15))
    
    # 3. Patient Clinical Profile
    story.append(Paragraph("1. Patient Clinical Profile", section_heading))
    age_val = record.get('age')
    sex_val = record.get('sex') or 'N/A'
    smoker_val = record.get('smoker') or 'N/A'
    weight_val = record.get('weight')
    height_val = record.get('height')
    duration_val = record.get('duration') or 'N/A'
    severity_val = record.get('severity') or 'N/A'
    
    conditions_raw = record.get('existing_conditions') or '[]'
    try:
        conditions_list = json.loads(conditions_raw) if isinstance(conditions_raw, str) else conditions_raw
        formatted_conditions = ", ".join([c.title() for c in conditions_list]) if conditions_list else 'None Reported'
    except Exception:
        formatted_conditions = 'None Reported'
        
    profile_data = [
        [
            Paragraph("<b>Age:</b> {}".format(age_val if age_val else 'N/A'), body_style),
            Paragraph("<b>Gender:</b> {}".format(sex_val), body_style)
        ],
        [
            Paragraph("<b>Weight:</b> {} kg".format(weight_val if weight_val else 'N/A'), body_style),
            Paragraph("<b>Height:</b> {} cm".format(height_val if height_val else 'N/A'), body_style)
        ],
        [
            Paragraph("<b>Smoking Status:</b> {}".format(smoker_val), body_style),
            Paragraph("<b>Medical History:</b> {}".format(formatted_conditions), body_style)
        ],
        [
            Paragraph("<b>Symptom Duration:</b> {}".format(duration_val), body_style),
            Paragraph("<b>Symptom Severity:</b> {}".format(severity_val), body_style)
        ]
    ]
    
    profile_table = Table(profile_data, colWidths=[doc.width/2.0, doc.width/2.0])
    profile_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), light_bg),
        ('BOX', (0, 0), (-1, -1), 0.5, colors.HexColor('#E2E8F0')),
        ('PADDING', (0, 0), (-1, -1), 8),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
    ]))
    story.append(profile_table)
    story.append(Spacer(1, 15))
    
    # 4. Symptoms Analyzed
    story.append(Paragraph("2. Symptoms Analyzed", section_heading))
    symptoms = json.loads(record['symptoms']) if isinstance(record['symptoms'], str) else record['symptoms']
    formatted_symptoms = [s.replace('_', ' ').title() for s in symptoms]
    symptoms_text = ", ".join(formatted_symptoms)
    story.append(Paragraph(symptoms_text, body_style))
    story.append(Spacer(1, 15))
    
    # 5. Assessment Prediction Results
    story.append(Paragraph("3. Assessment Result", section_heading))
    
    disease = record['predicted_disease']
    confidence = float(record['confidence'])
    recommendation = record.get('recommendation') or "Consult a General Physician."
    
    if confidence >= 80:
        conf_color = colors.HexColor('#27AE60')
        conf_label = "HIGH CONFIDENCE"
    elif confidence >= 50:
        conf_color = colors.HexColor('#F39C12')
        conf_label = "MEDIUM CONFIDENCE"
    else:
        conf_color = colors.HexColor('#C0392B')
        conf_label = "LOW CONFIDENCE"
        
    result_data = [
        [
            Paragraph("<b>Primary Suspected Condition:</b>", body_style),
            Paragraph("<font color='{}'><b>{}</b></font>".format(primary_color.hexval(), disease), ParagraphStyle('DiseaseName', parent=body_style, fontSize=11, fontName='Helvetica-Bold'))
        ],
        [
            Paragraph("<b>AI Confidence Score:</b>", body_style),
            Paragraph("<font color='{}'><b>{}% ({})</b></font>".format(conf_color.hexval(), confidence, conf_label), bold_body_style)
        ],
        [
            Paragraph("<b>Specialist Recommendation:</b>", body_style),
            Paragraph("<font color='{}'><b>{}</b></font>".format(accent_color.hexval(), recommendation), bold_body_style)
        ]
    ]
    
    result_table = Table(result_data, colWidths=[180, doc.width - 180])
    result_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), light_bg),
        ('PADDING', (0, 0), (-1, -1), 10),
        ('BOX', (0, 0), (-1, -1), 1, colors.HexColor('#E2E8F0')),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(result_table)
    story.append(Spacer(1, 15))
    
    # 6. Recommended Precautions
    story.append(Paragraph("4. Recommended Precautions", section_heading))
    precautions = json.loads(record['precautions']) if isinstance(record['precautions'], str) else record['precautions']
    
    precaution_list = []
    for idx, prec in enumerate(precautions, 1):
        precaution_list.append([
            Paragraph("<b>{}.</b>".format(idx), bold_body_style),
            Paragraph(prec, body_style)
        ])
    
    prec_table = Table(precaution_list, colWidths=[15, doc.width - 15])
    prec_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 2),
    ]))
    story.append(prec_table)
    story.append(Spacer(1, 20))
    
    # 7. Disclaimer (Keep together at bottom)
    disclaimer_box = []
    disclaimer_box.append(Paragraph("<b>IMPORTANT MEDICAL DISCLAIMER:</b>", ParagraphStyle('DisclaimerTitle', parent=disclaimer_style, fontName='Helvetica-Bold', textColor=accent_color)))
    disclaimer_box.append(Spacer(1, 3))
    disclaimer_box.append(Paragraph(
        "This report is generated by an Artificial Intelligence (AI) model based on self-reported symptoms and patient-entered clinical profiles. "
        "It is intended solely for educational and informational purposes, and does NOT constitute professional medical advice, diagnosis, treatment, or a clinical decision. "
        "Always seek the direct advice of your physician or other qualified health provider with any questions you may have regarding a medical condition. "
        "If you think you may have a medical emergency, call your doctor or emergency services immediately.",
        disclaimer_style
    ))
    
    disclaimer_table = Table([[disclaimer_box]], colWidths=[doc.width])
    disclaimer_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#FFFDF0')),
        ('BOX', (0, 0), (-1, -1), 1, colors.HexColor('#F39C12')),
        ('PADDING', (0, 0), (-1, -1), 10),
    ]))
    
    story.append(KeepTogether([disclaimer_table]))
    
    # Build PDF
    doc.build(story)
    buffer.seek(0)
    return buffer

@app.route('/api/history/<int:record_id>/pdf', methods=['GET'])
def get_pdf_report(record_id):
    try:
        conn = sqlite3.connect(DB_NAME)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM predictions WHERE id = ?', (record_id,))
        row = cursor.fetchone()
        conn.close()
        
        if not row:
            return jsonify({'error': 'Record not found'}), 404
            
        record = {
            'id': row['id'],
            'timestamp': row['timestamp'],
            'symptoms': row['symptoms'],
            'predicted_disease': row['predicted_disease'],
            'confidence': row['confidence'],
            'precautions': row['precautions'],
            'age': row['age'] if 'age' in row.keys() else None,
            'sex': row['sex'] if 'sex' in row.keys() else None,
            'smoker': row['smoker'] if 'smoker' in row.keys() else None,
            'weight': row['weight'] if 'weight' in row.keys() else None,
            'height': row['height'] if 'height' in row.keys() else None,
            'existing_conditions': row['existing_conditions'] if 'existing_conditions' in row.keys() else None,
            'duration': row['duration'] if 'duration' in row.keys() else None,
            'severity': row['severity'] if 'severity' in row.keys() else None,
            'recommendation': row['recommendation'] if 'recommendation' in row.keys() else None
        }
        
        pdf_buffer = generate_medical_report_pdf(record)
        
        return send_file(
            pdf_buffer,
            mimetype='application/pdf',
            as_attachment=True,
            download_name=f'Medical_Report_{record_id}.pdf'
        )
    except Exception as e:
        print(f"Error generating PDF: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/reminders', methods=['GET'])
def get_reminders():
    try:
        conn = sqlite3.connect(DB_NAME)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM reminders ORDER BY id DESC')
        rows = cursor.fetchall()
        conn.close()
        
        reminders_list = []
        for row in rows:
            reminders_list.append({
                'id': row['id'],
                'medicine_name': row['medicine_name'],
                'alarm_time': row['alarm_time'],
                'dosage': row['dosage'],
                'repeat_days': json.loads(row['repeat_days']),
                'label_color': row['label_color']
            })
        return jsonify(reminders_list)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/reminders', methods=['POST'])
def add_reminder():
    try:
        data = request.json
        medicine_name = data.get('medicine_name')
        alarm_time = data.get('alarm_time')
        dosage = data.get('dosage')
        repeat_days = data.get('repeat_days', [])
        label_color = data.get('label_color', 'blue')
        
        if not medicine_name or not alarm_time or not dosage:
            return jsonify({'error': 'Missing required fields'}), 400
            
        conn = sqlite3.connect(DB_NAME)
        cursor = conn.cursor()
        cursor.execute('''
        INSERT INTO reminders (medicine_name, alarm_time, dosage, repeat_days, label_color)
        VALUES (?, ?, ?, ?, ?)
        ''', (medicine_name, alarm_time, dosage, json.dumps(repeat_days), label_color))
        inserted_id = cursor.lastrowid
        conn.commit()
        conn.close()
        
        return jsonify({
            'id': inserted_id,
            'medicine_name': medicine_name,
            'alarm_time': alarm_time,
            'dosage': dosage,
            'repeat_days': repeat_days,
            'label_color': label_color
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/reminders/<int:reminder_id>', methods=['DELETE'])
def delete_reminder(reminder_id):
    try:
        conn = sqlite3.connect(DB_NAME)
        cursor = conn.cursor()
        cursor.execute('DELETE FROM reminders WHERE id = ?', (reminder_id,))
        conn.commit()
        conn.close()
        return jsonify({'success': True, 'message': f'Reminder {reminder_id} deleted.'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/chat', methods=['POST'])
def chatbot_chat():
    try:
        data = request.json or {}
        message = data.get('message', '').lower().strip()
        
        if not message:
            return jsonify({'reply': "I didn't catch that. How can I help you today?"})
            
        # 1. Warm greetings
        greetings = ['hello', 'hi', 'hey', 'greetings', 'sup', 'who are you', 'how are you', 'chatbot', 'aura']
        if any(g in message for g in greetings):
            return jsonify({
                'reply': "Hello! I am Aura, your health precautions assistant. You can tell me what symptoms or conditions you are experiencing (e.g., fever, cough, COVID-19), and I will guide you on the best precautions to take."
            })
            
        # 2. Support / Thanks
        thanks = ['thank you', 'thanks', 'cool', 'awesome', 'ok', 'okay', 'got it']
        if any(t in message for t in thanks):
            return jsonify({
                'reply': "You're very welcome! Remember, I am here to provide precautions, but always consult a physician for official medical diagnoses. Is there anything else you'd like to check?"
            })
            
        # 3. Check for disease matches in precautions dictionary
        matched_diseases = []
        for disease in precautions_dict.keys():
            if disease.lower() in message:
                matched_diseases.append(disease)
                 
        if matched_diseases:
            disease = matched_diseases[0]
            precs = precautions_dict[disease]
            precs_str = "\n".join([f"• {p}" for p in precs])
            return jsonify({
                'reply': f"For **{disease}**, the recommended precautions are:\n\n{precs_str}\n\n*Note: Please consult a physician immediately if symptoms worsen.*"
            })
            
        # 4. Check for symptom keywords and map to typical precautions
        symptom_precautions = {
            'fever': ["Monitor temperature regularly.", "Stay well-hydrated with water and oral rehydration solutions.", "Get plenty of rest.", "Take paracetamol if advised by a doctor."],
            'cough': ["Drink warm fluids like herbal tea or warm water with honey.", "Use steam inhalation to soothe airways.", "Get plenty of rest.", "Avoid smoking and exposure to cold air."],
            'sneezing': ["Keep tissue handy and wash hands regularly.", "Stay away from dusty environments.", "Consider taking antihistamines if it is allergy-related."],
            'sore throat': ["Gargle with warm salt water several times a day.", "Drink warm liquids and stay hydrated.", "Use throat lozenges."],
            'headache': ["Rest in a quiet, dark room.", "Apply a cold or warm compress to your forehead.", "Stay hydrated.", "Take mild pain relievers under advice."],
            'breathing': ["**EMERGENCY WARNING:** Seek immediate medical attention or call emergency services.", "Rest in an upright position.", "Avoid physical exertion."],
            'smell': ["Isolate yourself.", "Monitor oxygen levels.", "Get tested for COVID-19.", "Rest and stay hydrated."],
            'taste': ["Isolate yourself.", "Monitor oxygen levels.", "Get tested for COVID-19.", "Rest and stay hydrated."],
            'muscle pain': ["Get plenty of rest.", "Take warm baths.", "Take over-the-counter pain relievers if appropriate."],
            'weakness': ["Eat a light, nutritious diet.", "Stay hydrated.", "Rest as much as possible."]
        }
        
        matched_symptoms = []
        for sym_key in symptom_precautions.keys():
            if sym_key in message:
                matched_symptoms.append(sym_key)
                 
        if matched_symptoms:
            reply_parts = []
            for sym in matched_symptoms:
                precs = symptom_precautions[sym]
                precs_str = "\n".join([f"  • {p}" for p in precs])
                reply_parts.append(f"For **{sym.title()}**:\n{precs_str}")
                 
            combined_reply = "\n\n".join(reply_parts)
            return jsonify({
                'reply': f"Based on your description, here are precautions for your symptom(s):\n\n{combined_reply}\n\n*Disclaimer: This chatbot is for educational guidelines. If you have severe symptoms, seek professional medical care.*"
            })
            
        # 5. Default fallback
        return jsonify({
            'reply': "I understand you have health questions, but I couldn't identify specific symptoms in your message. Could you tell me more about what you're feeling? (e.g. 'I have a fever', 'What are the precautions for cough?')"
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5099)
