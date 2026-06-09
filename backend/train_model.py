import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
import joblib
import json
import os

# Ensure models directory exists
os.makedirs('models', exist_ok=True)
os.makedirs('data', exist_ok=True)

# Define disease to symptoms mapping
disease_symptoms = {
    'Common Cold': ['sneezing', 'runny_nose', 'sore_throat', 'cough', 'fever'],
    'Influenza': ['fever', 'muscle_pain', 'headache', 'fatigue', 'chills', 'cough'],
    'COVID-19': ['cough', 'fever', 'loss_of_taste', 'loss_of_smell', 'fatigue', 'difficulty_breathing'],
    'Malaria': ['fever', 'chills', 'sweating', 'headache', 'nausea', 'muscle_pain'],
    'Dengue': ['fever', 'severe_headache', 'joint_pain', 'rash', 'nausea'],
    'Typhoid': ['fever', 'abdominal_pain', 'headache', 'weakness', 'rash'],
    'Allergy': ['sneezing', 'watery_eyes', 'runny_nose', 'itchy_skin'],
    'Bronchitis': ['cough', 'difficulty_breathing', 'fever', 'fatigue', 'chest_pain'],
    'Pneumonia': ['fever', 'cough', 'difficulty_breathing', 'chest_pain', 'chills', 'fatigue'],
    'Heart Attack / Angina': ['chest_pain', 'difficulty_breathing', 'weakness', 'nausea', 'headache'],
    'GERD': ['chest_pain', 'nausea'],
    'Asthma Exacerbation': ['difficulty_breathing', 'cough']
}

# Define precautions
disease_precautions = {
    'Common Cold': ['Rest and sleep', 'Drink plenty of fluids', 'Take over-the-counter cold medicines'],
    'Influenza': ['Rest', 'Stay hydrated', 'Take antiviral drugs if prescribed', 'Use pain relievers'],
    'COVID-19': ['Isolate yourself', 'Monitor oxygen levels', 'Seek medical attention if breathing difficulties occur', 'Wear a mask'],
    'Malaria': ['Consult a doctor immediately for antimalarial drugs', 'Avoid mosquito bites', 'Use mosquito nets'],
    'Dengue': ['Drink fluids', 'Rest', 'Take paracetamol (avoid aspirin/ibuprofen)', 'Monitor platelet count'],
    'Typhoid': ['Take prescribed antibiotics', 'Eat clean and fully cooked food', 'Drink purified water'],
    'Allergy': ['Identify and avoid allergens', 'Take antihistamines', 'Consult an allergist'],
    'Bronchitis': ['Inhale steam or use humidifier', 'Avoid smoking and secondhand smoke', 'Stay hydrated', 'Rest and get plenty of sleep'],
    'Pneumonia': ['Get prescription antibiotics or antivirals', 'Get plenty of rest', 'Stay hydrated with warm liquids', 'Avoid cold environments'],
    'Heart Attack / Angina': ['**CALL EMERGENCY SERVICES (911) IMMEDIATELY**', 'Sit down and remain calm', 'Take aspirin if advised by emergency services', 'Chew nitroglycerin if previously prescribed'],
    'GERD': ['Avoid spicy, greasy, or acidic foods', 'Do not lie down within 2-3 hours of eating', 'Eat smaller, more frequent meals', 'Consider antacids under advice'],
    'Asthma Exacerbation': ['Use your quick-relief rescue inhaler (albuterol)', 'Sit upright and loosen tight clothing', 'Stay calm and breathe slowly', 'Seek emergency care if symptoms do not improve']
}

# Extract all unique symptoms
all_symptoms = set()
for symptoms in disease_symptoms.values():
    all_symptoms.update(symptoms)
all_symptoms = sorted(list(all_symptoms))

# Generate synthetic dataset
# We'll create multiple samples per disease with some variations (dropping 1 or 2 symptoms) to make the model robust
data = []
labels = []

num_samples_per_disease = 50

for disease, symptoms in disease_symptoms.items():
    for _ in range(num_samples_per_disease):
        # Create a sample
        sample = {s: 0 for s in all_symptoms}
        
        # Determine how many symptoms to keep (at least 2, up to all)
        num_symptoms_to_keep = np.random.randint(2, len(symptoms) + 1) if len(symptoms) > 2 else len(symptoms)
        
        # Select random symptoms from the disease's typical symptoms
        selected_symptoms = np.random.choice(symptoms, num_symptoms_to_keep, replace=False)
        
        for s in selected_symptoms:
            sample[s] = 1
            
        # Add some noise (randomly add 1 unrelated symptom with low probability)
        if np.random.random() < 0.2:
            random_symptom = np.random.choice(all_symptoms)
            sample[random_symptom] = 1
            
        data.append(sample)
        labels.append(disease)

# Create DataFrame
df = pd.DataFrame(data)
df['target'] = labels

# Save dataset to CSV for inspection
df.to_csv('data/dataset.csv', index=False)

# Save precautions to JSON
with open('data/precautions.json', 'w') as f:
    json.dump(disease_precautions, f, indent=4)

# Prepare for training
X = df.drop('target', axis=1)
y = df['target']

# Train Random Forest Classifier
clf = RandomForestClassifier(n_estimators=100, random_state=42)
clf.fit(X, y)

# Save the model and feature names
joblib.dump(clf, 'models/rf_model.pkl')
joblib.dump(list(X.columns), 'models/feature_names.pkl')

print("Model trained successfully.")
print(f"Number of samples: {len(df)}")
print(f"Number of features (symptoms): {len(X.columns)}")
print("Artifacts saved in 'models/' and 'data/' directories.")
