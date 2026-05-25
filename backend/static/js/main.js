// ============================================
// AuraHealth AI — Main JavaScript
// Features: Voice Input + Nearest Hospitals + PDF Report
// ============================================

let allSymptoms = [];
let hospitalMap = null;
let hospitalMarkers = [];
// Cache last results for PDF generation
let lastPredictionData = null;
let lastSelectedSymptoms = [];
let lastHospitalsData = [];

document.addEventListener('DOMContentLoaded', () => {
    const symptomSelect = $('#symptom-select');
    if (symptomSelect.length > 0) {
        initIndexPage();
    }
});

// ============================================
// INDEX PAGE INIT
// ============================================
function initIndexPage() {
    // Fetch available symptoms
    fetch('/api/symptoms')
        .then(response => response.json())
        .then(symptoms => {
            allSymptoms = symptoms;
            const selectElement = $('#symptom-select');
            symptoms.forEach(symptom => {
                const formattedSymptom = symptom.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
                selectElement.append(new Option(formattedSymptom, symptom));
            });

            // Initialize Select2
            selectElement.select2({
                placeholder: "Type to search symptoms...",
                allowClear: true,
                width: '100%'
            });
        })
        .catch(err => console.error("Error fetching symptoms:", err));

    // Predict button
    const predictBtn = document.getElementById('predict-btn');
    if (predictBtn) {
        predictBtn.addEventListener('click', runPrediction);
    }

    // Find hospitals button
    const findHospitalsBtn = document.getElementById('find-hospitals-btn');
    if (findHospitalsBtn) {
        findHospitalsBtn.addEventListener('click', () => {
            const section = document.getElementById('hospital-section');
            section.classList.remove('hidden');
            section.scrollIntoView({ behavior: 'smooth', block: 'start' });
            findNearestHospitals();
        });
    }

    // PDF download button
    const pdfBtn = document.getElementById('download-pdf-btn');
    if (pdfBtn) {
        pdfBtn.addEventListener('click', generatePDFReport);
    }

    // Init voice input
    initVoiceInput();
}

// ============================================
// PREDICTION
// ============================================
function runPrediction() {
    const selectedSymptoms = $('#symptom-select').val();

    if (!selectedSymptoms || selectedSymptoms.length === 0) {
        showToast("Please select at least one symptom.", "warning");
        return;
    }

    // Cache selected symptoms for PDF
    lastSelectedSymptoms = selectedSymptoms;
    lastHospitalsData = []; // reset hospitals on new prediction

    // UI Transitions
    document.getElementById('empty-state').classList.add('hidden');
    document.getElementById('results-content').classList.add('hidden');
    document.getElementById('loading-state').classList.remove('hidden');

    // Hide hospital section on new prediction
    document.getElementById('hospital-section').classList.add('hidden');

    if (window.innerWidth <= 768) {
        document.getElementById('results-container').scrollIntoView({ behavior: 'smooth' });
    }

    fetch('/api/predict', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ symptoms: selectedSymptoms }),
    })
    .then(response => response.json())
    .then(data => {
        if (data.error) {
            showToast(data.error, "error");
            showEmptyState();
            return;
        }
        displayResults(data);
    })
    .catch(error => {
        console.error('Error during prediction:', error);
        showToast("Failed to get prediction. Ensure backend is running.", "error");
        showEmptyState();
    });
}

function showEmptyState() {
    document.getElementById('loading-state').classList.add('hidden');
    document.getElementById('empty-state').classList.remove('hidden');
}

function displayResults(data) {
    document.getElementById('loading-state').classList.add('hidden');

    // Cache for PDF generation
    lastPredictionData = data;

    document.getElementById('predicted-disease').textContent = data.disease.replace(/_/g, ' ');
    document.getElementById('confidence-percentage').textContent = data.confidence + '%';

    const badge = document.getElementById('confidence-badge');
    if (data.confidence >= 80) {
        badge.textContent = 'High Confidence';
        badge.style.cssText = 'color:var(--success);background:rgba(34,197,94,0.2);border-color:rgba(34,197,94,0.3)';
    } else if (data.confidence >= 50) {
        badge.textContent = 'Moderate Confidence';
        badge.style.cssText = 'color:var(--warning);background:rgba(245,158,11,0.2);border-color:rgba(245,158,11,0.3)';
    } else {
        badge.textContent = 'Low Confidence';
        badge.style.cssText = 'color:var(--danger);background:rgba(239,68,68,0.2);border-color:rgba(239,68,68,0.3)';
    }

    const precautionsList = document.getElementById('precautions-list');
    precautionsList.innerHTML = '';
    data.precautions.forEach(precaution => {
        const li = document.createElement('li');
        li.textContent = precaution;
        precautionsList.appendChild(li);
    });

    document.getElementById('results-content').classList.remove('hidden');
    setTimeout(() => {
        document.getElementById('confidence-bar').style.width = data.confidence + '%';
    }, 50);
}

// ============================================
// VOICE INPUT
// ============================================
function initVoiceInput() {
    const voiceBtn = document.getElementById('voice-btn');
    if (!voiceBtn) return;

    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;

    if (!SpeechRecognition) {
        document.getElementById('voice-status').textContent = 'Voice input not supported in this browser. Try Chrome or Edge.';
        voiceBtn.disabled = true;
        voiceBtn.style.opacity = '0.4';
        voiceBtn.style.cursor = 'not-allowed';
        return;
    }

    const recognition = new SpeechRecognition();
    recognition.lang = 'en-US';
    recognition.interimResults = true;
    recognition.continuous = true;

    let isRecording = false;

    voiceBtn.addEventListener('click', () => {
        if (isRecording) {
            recognition.stop();
        } else {
            recognition.start();
        }
    });

    recognition.onstart = () => {
        isRecording = true;
        voiceBtn.classList.add('recording');
        document.getElementById('mic-icon').className = 'fa-solid fa-stop';
        document.getElementById('voice-status').textContent = 'Listening... speak symptom names clearly';
        hideFeedback();
    };

    recognition.onend = () => {
        isRecording = false;
        voiceBtn.classList.remove('recording');
        document.getElementById('mic-icon').className = 'fa-solid fa-microphone';
        document.getElementById('voice-status').textContent = 'Click the mic and speak symptoms clearly';
        document.getElementById('voice-transcript').textContent = '';
    };

    recognition.onerror = (event) => {
        isRecording = false;
        voiceBtn.classList.remove('recording');
        document.getElementById('mic-icon').className = 'fa-solid fa-microphone';

        let msg = 'Voice error: ' + event.error;
        if (event.error === 'not-allowed') msg = 'Microphone access denied. Please allow mic access.';
        if (event.error === 'no-speech') msg = 'No speech detected. Try again.';
        document.getElementById('voice-status').textContent = msg;
    };

    recognition.onresult = (event) => {
        let finalTranscript = '';
        let interimTranscript = '';

        for (let i = event.resultIndex; i < event.results.length; i++) {
            const transcript = event.results[i][0].transcript;
            if (event.results[i].isFinal) {
                finalTranscript += transcript;
            } else {
                interimTranscript += transcript;
            }
        }

        document.getElementById('voice-transcript').textContent = interimTranscript || finalTranscript;

        if (finalTranscript) {
            processVoiceInput(finalTranscript.trim());
        }
    };
}

function processVoiceInput(transcript) {
    if (allSymptoms.length === 0) return;

    const words = transcript.toLowerCase().replace(/[^a-z\s]/g, '').trim();
    const matched = [];

    // Try to match phrases and individual words against symptoms
    allSymptoms.forEach(symptom => {
        const symptomNormalized = symptom.replace(/_/g, ' ').toLowerCase();
        if (words.includes(symptomNormalized)) {
            matched.push(symptom);
        }
    });

    // Fallback: fuzzy token match
    if (matched.length === 0) {
        const inputTokens = words.split(/\s+/);
        allSymptoms.forEach(symptom => {
            const symTokens = symptom.replace(/_/g, ' ').toLowerCase().split(/\s+/);
            const overlap = symTokens.filter(t => inputTokens.some(iw => levenshtein(iw, t) <= 1)).length;
            if (overlap >= Math.ceil(symTokens.length * 0.6)) {
                matched.push(symptom);
            }
        });
    }

    if (matched.length > 0) {
        const selectEl = $('#symptom-select');
        let addedCount = 0;

        matched.forEach(symptom => {
            const currentVals = selectEl.val() || [];
            if (!currentVals.includes(symptom)) {
                // Check if option exists, if not create it
                if (selectEl.find(`option[value="${symptom}"]`).length === 0) {
                    const label = symptom.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
                    selectEl.append(new Option(label, symptom, true, true));
                } else {
                    const newVals = [...currentVals, symptom];
                    selectEl.val(newVals).trigger('change');
                }
                addedCount++;
            }
        });

        selectEl.trigger('change');

        showFeedback(`✓ Added: ${matched.map(s => s.replace(/_/g, ' ')).join(', ')}`);
    } else {
        showFeedback(`Could not match "${transcript}" to known symptoms. Try speaking more clearly.`, true);
    }
}

// Simple Levenshtein distance for fuzzy matching
function levenshtein(a, b) {
    if (a.length === 0) return b.length;
    if (b.length === 0) return a.length;
    const matrix = Array.from({ length: b.length + 1 }, (_, i) => [i]);
    matrix[0] = Array.from({ length: a.length + 1 }, (_, i) => i);
    for (let i = 1; i <= b.length; i++) {
        for (let j = 1; j <= a.length; j++) {
            const cost = a[j - 1] === b[i - 1] ? 0 : 1;
            matrix[i][j] = Math.min(
                matrix[i - 1][j] + 1,
                matrix[i][j - 1] + 1,
                matrix[i - 1][j - 1] + cost
            );
        }
    }
    return matrix[b.length][a.length];
}

function showFeedback(text, isError = false) {
    const fb = document.getElementById('voice-feedback');
    const fbText = document.getElementById('voice-feedback-text');
    fbText.textContent = text;
    fb.classList.remove('hidden');
    if (isError) {
        fb.style.background = 'rgba(239, 68, 68, 0.1)';
        fb.style.color = 'var(--danger)';
        fb.style.borderColor = 'rgba(239, 68, 68, 0.2)';
    } else {
        fb.style.background = 'rgba(34, 197, 94, 0.1)';
        fb.style.color = 'var(--success)';
        fb.style.borderColor = 'rgba(34, 197, 94, 0.2)';
    }
    clearTimeout(fb._timer);
    fb._timer = setTimeout(() => fb.classList.add('hidden'), 4000);
}

function hideFeedback() {
    document.getElementById('voice-feedback').classList.add('hidden');
}

// ============================================
// NEAREST HOSPITALS
// ============================================
function findNearestHospitals() {
    const loading = document.getElementById('hospital-loading');
    const error = document.getElementById('hospital-error');
    const results = document.getElementById('hospital-results');
    const countBadge = document.getElementById('hospital-count-badge');

    // Reset state
    loading.classList.remove('hidden');
    error.classList.add('hidden');
    results.classList.add('hidden');
    countBadge.textContent = '';
    updateHospitalLoadingText('Detecting your location...');

    // Try browser geolocation first (low accuracy = fast, no GPS needed)
    if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(
            position => {
                const { latitude, longitude } = position.coords;
                updateHospitalLoadingText('Location found! Searching for nearby hospitals...');
                fetchHospitalsFromOverpass(latitude, longitude);
            },
            err => {
                console.warn('Browser geolocation failed (code ' + err.code + '), falling back to IP location...');
                // Fallback: use IP-based geolocation
                fallbackToIPGeolocation();
            },
            {
                enableHighAccuracy: false,  // Use network location, much faster on desktops
                timeout: 8000,              // 8 seconds
                maximumAge: 300000          // Accept cached location up to 5 min old
            }
        );
    } else {
        // Browser doesn't support geolocation at all — use IP fallback
        fallbackToIPGeolocation();
    }
}

function updateHospitalLoadingText(msg) {
    const loading = document.getElementById('hospital-loading');
    const p = loading.querySelector('p');
    if (p) p.textContent = msg;
}

function fallbackToIPGeolocation() {
    updateHospitalLoadingText('Using IP-based location (approximate)...');

    // ip-api.com — free, no API key needed, returns lat/lon from IP
    fetch('http://ip-api.com/json/?fields=status,lat,lon,city,regionName,country')
        .then(res => res.json())
        .then(data => {
            if (data.status === 'success') {
                updateHospitalLoadingText(`Location: ${data.city}, ${data.regionName}. Searching hospitals...`);
                fetchHospitalsFromOverpass(data.lat, data.lon);
            } else {
                showHospitalError('Could not determine your location automatically. Please ensure location permissions are granted and try again.');
            }
        })
        .catch(() => {
            showHospitalError('Location services unavailable. Please allow location access in your browser settings and reload the page.');
        });
}

function fetchHospitalsFromOverpass(lat, lng) {
    const radius = 5000; // 5km radius
    // Overpass API query for hospitals, clinics, and medical centres
    const query = `
        [out:json][timeout:25];
        (
          node["amenity"="hospital"](around:${radius},${lat},${lng});
          node["amenity"="clinic"](around:${radius},${lat},${lng});
          node["amenity"="doctors"](around:${radius},${lat},${lng});
          way["amenity"="hospital"](around:${radius},${lat},${lng});
          way["amenity"="clinic"](around:${radius},${lat},${lng});
        );
        out center 30;
    `;

    const url = 'https://overpass-api.de/api/interpreter';

    fetch(url, {
        method: 'POST',
        body: query,
        headers: { 'Content-Type': 'text/plain' }
    })
    .then(res => res.json())
    .then(data => {
        const elements = data.elements || [];

        // Normalize: ways have center, nodes have direct lat/lng
        const hospitals = elements.map(el => ({
            id: el.id,
            name: el.tags?.name || el.tags?.['name:en'] || 'Unnamed Medical Facility',
            lat: el.lat || el.center?.lat,
            lng: el.lon || el.center?.lon,
            type: el.tags?.amenity || 'hospital',
            phone: el.tags?.phone || el.tags?.['contact:phone'] || null,
            website: el.tags?.website || null
        }))
        .filter(h => h.lat && h.lng)
        .map(h => ({
            ...h,
            distance: haversineDistance(lat, lng, h.lat, h.lng)
        }))
        .sort((a, b) => a.distance - b.distance)
        .slice(0, 8);

        document.getElementById('hospital-loading').classList.add('hidden');

        if (hospitals.length === 0) {
            showHospitalError('No hospitals found within 5km of your location. Try allowing a larger range.');
            return;
        }

        document.getElementById('hospital-count-badge').textContent = `${hospitals.length} found nearby`;
        document.getElementById('hospital-results').classList.remove('hidden');
        renderHospitalMap(lat, lng, hospitals);
        renderHospitalList(hospitals);
        // Cache for PDF
        lastHospitalsData = hospitals;
    })
    .catch(err => {
        console.error('Overpass API error:', err);
        showHospitalError('Failed to fetch hospital data. Check your internet connection and try again.');
    });
}

function haversineDistance(lat1, lng1, lat2, lng2) {
    const R = 6371000; // Earth's radius in meters
    const phi1 = lat1 * Math.PI / 180;
    const phi2 = lat2 * Math.PI / 180;
    const dPhi = (lat2 - lat1) * Math.PI / 180;
    const dLambda = (lng2 - lng1) * Math.PI / 180;

    const a = Math.sin(dPhi / 2) ** 2 +
              Math.cos(phi1) * Math.cos(phi2) * Math.sin(dLambda / 2) ** 2;
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c; // distance in meters
}

function formatDistance(meters) {
    if (meters < 1000) return `${Math.round(meters)} m`;
    return `${(meters / 1000).toFixed(1)} km`;
}

function renderHospitalMap(userLat, userLng, hospitals) {
    // Destroy existing map if any
    if (hospitalMap) {
        hospitalMap.remove();
        hospitalMap = null;
    }

    hospitalMap = L.map('hospital-map', {
        zoomControl: true,
        attributionControl: true
    }).setView([userLat, userLng], 14);

    // Dark-styled tile layer
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '© OpenStreetMap contributors, © CARTO',
        subdomains: 'abcd',
        maxZoom: 19
    }).addTo(hospitalMap);

    // User marker
    const userIcon = L.divIcon({
        className: '',
        html: `<div style="
            width:18px;height:18px;
            background:linear-gradient(135deg,#6366f1,#ec4899);
            border-radius:50%;
            border:3px solid white;
            box-shadow:0 0 0 4px rgba(99,102,241,0.3);
        "></div>`,
        iconSize: [18, 18],
        iconAnchor: [9, 9]
    });

    L.marker([userLat, userLng], { icon: userIcon })
        .addTo(hospitalMap)
        .bindPopup('<strong style="color:#a5b4fc">📍 Your Location</strong>');

    // Hospital markers
    hospitals.forEach((hospital, index) => {
        const hospitalIcon = L.divIcon({
            className: '',
            html: `<div style="
                width:32px;height:32px;
                background:linear-gradient(135deg,#06b6d4,#0891b2);
                border-radius:50%;
                border:2px solid white;
                color:white;
                font-size:11px;
                font-weight:700;
                display:flex;align-items:center;justify-content:center;
                box-shadow:0 2px 8px rgba(6,182,212,0.5);
                font-family:'Outfit',sans-serif;
            ">${index + 1}</div>`,
            iconSize: [32, 32],
            iconAnchor: [16, 16]
        });

        const amenityLabel = hospital.type === 'clinic' ? '🏥 Clinic' :
                             hospital.type === 'doctors' ? '👨‍⚕️ Doctor' : '🏨 Hospital';

        const popupContent = `
            <div style="min-width:180px">
                <p style="font-size:0.75rem;color:#06b6d4;margin:0 0 4px">${amenityLabel}</p>
                <strong style="font-size:0.95rem">${hospital.name}</strong>
                <p style="color:#94a3b8;font-size:0.8rem;margin:6px 0 0">📏 ${formatDistance(hospital.distance)} away</p>
                <a href="https://www.google.com/maps/dir/?api=1&destination=${hospital.lat},${hospital.lng}"
                   target="_blank" rel="noopener"
                   style="display:inline-block;margin-top:8px;padding:4px 10px;background:#06b6d4;color:white;border-radius:6px;text-decoration:none;font-size:0.78rem">
                   🗺 Get Directions
                </a>
            </div>
        `;

        L.marker([hospital.lat, hospital.lng], { icon: hospitalIcon })
            .addTo(hospitalMap)
            .bindPopup(popupContent);
    });
}

function renderHospitalList(hospitals) {
    const list = document.getElementById('hospital-list');
    list.innerHTML = '';

    hospitals.forEach((hospital, index) => {
        const card = document.createElement('div');
        card.className = 'hospital-card';
        card.style.animationDelay = `${index * 0.07}s`;

        const amenityIcon = hospital.type === 'clinic' ? 'fa-clinic-medical' :
                            hospital.type === 'doctors' ? 'fa-user-doctor' : 'fa-hospital';

        card.innerHTML = `
            <div class="hospital-card-top">
                <div class="hospital-rank">${index + 1}</div>
                <div>
                    <div class="hospital-name">${hospital.name}</div>
                    <div style="font-size:0.75rem;color:var(--text-muted);margin-top:2px;text-transform:capitalize">
                        <i class="fa-solid ${amenityIcon}" style="margin-right:4px;color:var(--hospital-accent)"></i>
                        ${hospital.type.replace('_', ' ')}
                    </div>
                </div>
            </div>
            <div class="hospital-card-bottom">
                <div class="hospital-distance">
                    <i class="fa-solid fa-location-dot"></i>
                    <span>${formatDistance(hospital.distance)}</span>
                </div>
                <a class="directions-link"
                   href="https://www.google.com/maps/dir/?api=1&destination=${hospital.lat},${hospital.lng}"
                   target="_blank" rel="noopener">
                    <i class="fa-solid fa-diamond-turn-right"></i> Directions
                </a>
            </div>
        `;

        // Click card to open popup on map
        card.addEventListener('click', () => {
            if (hospitalMap) {
                hospitalMap.setView([hospital.lat, hospital.lng], 16, { animate: true });
            }
        });

        list.appendChild(card);
    });
}

function showHospitalError(msg) {
    document.getElementById('hospital-loading').classList.add('hidden');
    document.getElementById('hospital-error').classList.remove('hidden');
    document.getElementById('hospital-error-msg').textContent = msg;
}

// ============================================
// TOAST NOTIFICATION
// ============================================
function showToast(message, type = 'info') {
    const existing = document.getElementById('toast-msg');
    if (existing) existing.remove();

    const toast = document.createElement('div');
    toast.id = 'toast-msg';

    const colors = {
        warning: { bg: 'rgba(245,158,11,0.15)', border: 'rgba(245,158,11,0.4)', color: '#f59e0b' },
        error:   { bg: 'rgba(239,68,68,0.15)',  border: 'rgba(239,68,68,0.4)',  color: '#ef4444' },
        info:    { bg: 'rgba(99,102,241,0.15)', border: 'rgba(99,102,241,0.4)', color: '#6366f1' },
    };
    const c = colors[type] || colors.info;

    Object.assign(toast.style, {
        position: 'fixed', bottom: '2rem', right: '2rem',
        padding: '0.9rem 1.4rem',
        background: c.bg, border: `1px solid ${c.border}`,
        color: c.color, borderRadius: '12px',
        fontFamily: 'Inter, sans-serif', fontWeight: '600',
        fontSize: '0.9rem', zIndex: '9999',
        backdropFilter: 'blur(12px)',
        boxShadow: '0 8px 24px rgba(0,0,0,0.3)',
        animation: 'fadeIn 0.3s ease',
        maxWidth: '320px'
    });

    toast.textContent = message;
    document.body.appendChild(toast);
    setTimeout(() => toast.remove(), 4000);
}

// ============================================
// HISTORY PAGE
// ============================================
function fetchHistory() {
    fetch('/api/history')
        .then(response => response.json())
        .then(data => {
            document.getElementById('history-loading').classList.add('hidden');

            if (data.length === 0) {
                document.getElementById('history-empty').classList.remove('hidden');
                return;
            }

            document.getElementById('history-content').classList.remove('hidden');
            const tbody = document.getElementById('history-tbody');

            data.forEach(item => {
                const tr = document.createElement('tr');
                const date = new Date(item.timestamp);
                const formattedDate = date.toLocaleString();

                const symptomsHtml = item.symptoms.map(s =>
                    `<span class="symptom-tag">${s.replace(/_/g, ' ')}</span>`
                ).join('');

                tr.innerHTML = `
                    <td>${formattedDate}</td>
                    <td>${symptomsHtml}</td>
                    <td style="font-weight:600;color:var(--primary);text-transform:capitalize">${item.predicted_disease.replace(/_/g, ' ')}</td>
                    <td>
                        <div style="display:flex;align-items:center;gap:10px;">
                            <span style="min-width:45px">${item.confidence.toFixed(1)}%</span>
                            <div style="width:100px;height:6px;background:rgba(255,255,255,0.1);border-radius:3px;">
                                <div style="width:${item.confidence}%;height:100%;background:var(--primary);border-radius:3px;"></div>
                            </div>
                        </div>
                    </td>
                `;
                tbody.appendChild(tr);
            });
        })
        .catch(err => {
            console.error("Error fetching history:", err);
            document.getElementById('history-loading').innerHTML = '<p style="color:var(--danger)">Error loading history data.</p>';
        });
}

// ============================================
// PDF MEDICAL REPORT GENERATION
// ============================================
function generatePDFReport() {
    if (!lastPredictionData) {
        showToast('Please run a symptom analysis first.', 'warning');
        return;
    }

    const btn = document.getElementById('download-pdf-btn');
    btn.classList.add('generating');
    btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Generating...';

    // Small delay to let the UI update
    setTimeout(() => {
        try {
            buildPDF();
        } catch (e) {
            console.error('PDF error:', e);
            showToast('Failed to generate PDF. Please try again.', 'error');
        } finally {
            btn.classList.remove('generating');
            btn.innerHTML = '<i class="fa-solid fa-file-medical"></i> Download PDF Report';
        }
    }, 100);
}

function buildPDF() {
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });

    const pageW = doc.internal.pageSize.getWidth();
    const pageH = doc.internal.pageSize.getHeight();
    const margin = 18;
    const contentW = pageW - margin * 2;
    let y = 0;

    // ── HEADER GRADIENT BAR ──────────────────────────────
    // Simulate gradient with multiple rects
    const headerH = 38;
    const steps = 60;
    for (let i = 0; i < steps; i++) {
        const t = i / steps;
        const r = Math.round(99  + (236 - 99)  * t);
        const g = Math.round(102 + (72  - 102) * t);
        const b = Math.round(241 + (153 - 241) * t);
        doc.setFillColor(r, g, b);
        doc.rect(i * (pageW / steps), 0, pageW / steps + 0.5, headerH, 'F');
    }

    // Logo text
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(20);
    doc.setTextColor(255, 255, 255);
    doc.text('AuraHealth AI', margin, 16);

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    doc.setTextColor(220, 220, 255);
    doc.text('Medical Symptom Analysis Report', margin, 23);

    // Report date (right aligned)
    const now = new Date();
    const dateStr = now.toLocaleDateString('en-IN', { day: '2-digit', month: 'long', year: 'numeric' });
    const timeStr = now.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });
    doc.setFontSize(8);
    doc.setTextColor(200, 200, 255);
    doc.text(`Generated: ${dateStr}  ${timeStr}`, pageW - margin, 16, { align: 'right' });
    doc.text('Report ID: AH-' + Date.now().toString().slice(-8), pageW - margin, 22, { align: 'right' });

    y = headerH + 10;

    // ── HELPER FUNCTIONS ─────────────────────────────────
    function sectionTitle(title, icon = '') {
        // Section line
        doc.setDrawColor(99, 102, 241);
        doc.setLineWidth(0.5);
        doc.line(margin, y, margin + contentW, y);
        y += 5;

        doc.setFont('helvetica', 'bold');
        doc.setFontSize(12);
        doc.setTextColor(99, 102, 241);
        doc.text((icon ? icon + '  ' : '') + title, margin, y);
        y += 7;

        doc.setTextColor(30, 30, 30);
    }

    function checkPageBreak(needed = 20) {
        if (y + needed > pageH - 20) {
            doc.addPage();
            y = 18;
        }
    }

    // ── SYMPTOMS SECTION ─────────────────────────────────
    sectionTitle('Reported Symptoms');

    const symptomNames = lastSelectedSymptoms.map(s =>
        s.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
    );

    // Render as pill-style chips using a table
    const chunkSize = 3;
    const symRows = [];
    for (let i = 0; i < symptomNames.length; i += chunkSize) {
        symRows.push(symptomNames.slice(i, i + chunkSize));
    }

    // Pad last row
    if (symRows.length > 0) {
        while (symRows[symRows.length - 1].length < chunkSize) {
            symRows[symRows.length - 1].push('');
        }
    }

    doc.autoTable({
        startY: y,
        head: [],
        body: symRows,
        theme: 'grid',
        margin: { left: margin, right: margin },
        styles: {
            fontSize: 9,
            cellPadding: 4,
            textColor: [40, 40, 80],
            fillColor: [238, 240, 255],
            lineColor: [180, 180, 220],
            lineWidth: 0.3,
            font: 'helvetica',
        },
        columnStyles: {
            0: { cellWidth: contentW / 3 },
            1: { cellWidth: contentW / 3 },
            2: { cellWidth: contentW / 3 },
        },
    });

    y = doc.lastAutoTable.finalY + 10;

    // ── DIAGNOSIS SECTION ────────────────────────────────
    checkPageBreak(55);
    sectionTitle('AI Diagnosis');

    const disease = lastPredictionData.disease.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
    const confidence = lastPredictionData.confidence;

    // Disease name box
    doc.setFillColor(238, 240, 255);
    doc.setDrawColor(99, 102, 241);
    doc.setLineWidth(0.4);
    doc.roundedRect(margin, y, contentW, 20, 3, 3, 'FD');

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(16);
    doc.setTextColor(60, 60, 180);
    doc.text(disease, margin + 5, y + 13);

    // Confidence badge
    const badgeColor = confidence >= 80 ? [34, 197, 94] : confidence >= 50 ? [245, 158, 11] : [239, 68, 68];
    const badgeLabel = confidence >= 80 ? 'HIGH CONFIDENCE' : confidence >= 50 ? 'MODERATE' : 'LOW CONFIDENCE';
    doc.setFillColor(...badgeColor);
    doc.roundedRect(pageW - margin - 45, y + 5, 45, 10, 2, 2, 'F');
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(8);
    doc.setTextColor(255, 255, 255);
    doc.text(badgeLabel, pageW - margin - 22.5, y + 11.5, { align: 'center' });

    y += 26;

    // Confidence bar
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    doc.setTextColor(80, 80, 80);
    doc.text('AI Confidence Score', margin, y);
    doc.text(`${confidence.toFixed(1)}%`, pageW - margin, y, { align: 'right' });
    y += 4;

    // Track background
    doc.setFillColor(220, 220, 235);
    doc.roundedRect(margin, y, contentW, 5, 2, 2, 'F');

    // Fill
    const fillW = (confidence / 100) * contentW;
    // Gradient fill via steps
    const barSteps = 40;
    for (let i = 0; i < barSteps; i++) {
        const t = i / barSteps;
        const r = Math.round(99  + (236 - 99)  * t);
        const g = Math.round(102 + (72  - 102) * t);
        const b = Math.round(241 + (153 - 241) * t);
        const sw = fillW / barSteps;
        doc.setFillColor(r, g, b);
        doc.rect(margin + i * sw, y, sw + 0.5, 5, 'F');
    }
    doc.setDrawColor(180, 180, 220);
    doc.setLineWidth(0.3);
    doc.roundedRect(margin, y, contentW, 5, 2, 2, 'S');

    y += 12;

    // ── PRECAUTIONS SECTION ──────────────────────────────
    checkPageBreak(30);
    sectionTitle('Recommended Precautions');

    const precautions = lastPredictionData.precautions;
    precautions.forEach((p, i) => {
        checkPageBreak(10);
        doc.setFillColor(i % 2 === 0 ? 250 : 245, i % 2 === 0 ? 252 : 248, 255);
        doc.rect(margin, y - 4, contentW, 9, 'F');

        doc.setFont('helvetica', 'bold');
        doc.setFontSize(9);
        doc.setTextColor(34, 197, 94);
        doc.text('✓', margin + 2, y + 1);

        doc.setFont('helvetica', 'normal');
        doc.setTextColor(40, 40, 60);
        const lines = doc.splitTextToSize(p, contentW - 12);
        doc.text(lines, margin + 9, y + 1);
        y += lines.length * 5.5 + 2;
    });

    y += 5;

    // ── NEARBY HOSPITALS SECTION ─────────────────────────
    if (lastHospitalsData && lastHospitalsData.length > 0) {
        checkPageBreak(20);
        sectionTitle('Nearby Medical Facilities');

        const hospitalRows = lastHospitalsData.map((h, i) => [
            `${i + 1}`,
            h.name,
            h.type.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase()),
            formatDistance(h.distance)
        ]);

        doc.autoTable({
            startY: y,
            head: [['#', 'Facility Name', 'Type', 'Distance']],
            body: hospitalRows,
            theme: 'striped',
            margin: { left: margin, right: margin },
            headStyles: {
                fillColor: [6, 182, 212],
                textColor: [255, 255, 255],
                fontStyle: 'bold',
                fontSize: 9,
            },
            bodyStyles: {
                fontSize: 8.5,
                textColor: [40, 40, 60],
            },
            alternateRowStyles: { fillColor: [240, 252, 255] },
            columnStyles: {
                0: { cellWidth: 10, halign: 'center' },
                1: { cellWidth: contentW * 0.52 },
                2: { cellWidth: contentW * 0.26 },
                3: { cellWidth: contentW * 0.15, halign: 'right' },
            },
        });

        y = doc.lastAutoTable.finalY + 10;
    }

    // ── DISCLAIMER ───────────────────────────────────────
    checkPageBreak(22);
    doc.setFillColor(255, 251, 235);
    doc.setDrawColor(245, 158, 11);
    doc.setLineWidth(0.4);
    doc.roundedRect(margin, y, contentW, 22, 3, 3, 'FD');

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(8.5);
    doc.setTextColor(180, 100, 0);
    doc.text('⚠  Medical Disclaimer', margin + 4, y + 7);

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(7.5);
    doc.setTextColor(120, 80, 0);
    const disclaimer = 'This report is generated by an AI-powered tool for informational purposes only. It does not constitute medical advice, diagnosis, or treatment. Always consult a qualified healthcare professional for any medical concerns.';
    const dLines = doc.splitTextToSize(disclaimer, contentW - 8);
    doc.text(dLines, margin + 4, y + 13);

    // ── FOOTER ───────────────────────────────────────────
    const totalPages = doc.internal.getNumberOfPages();
    for (let pg = 1; pg <= totalPages; pg++) {
        doc.setPage(pg);
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(7);
        doc.setTextColor(160, 160, 180);
        doc.text('AuraHealth AI  |  Powered by Machine Learning', margin, pageH - 8);
        doc.text(`Page ${pg} of ${totalPages}`, pageW - margin, pageH - 8, { align: 'right' });
        // Footer line
        doc.setDrawColor(200, 200, 220);
        doc.setLineWidth(0.3);
        doc.line(margin, pageH - 12, pageW - margin, pageH - 12);
    }

    // ── SAVE ─────────────────────────────────────────────
    const filename = `AuraHealth_Report_${disease.replace(/\s+/g, '_')}_${now.toISOString().slice(0,10)}.pdf`;
    doc.save(filename);
    showToast('PDF report downloaded successfully!', 'info');
}
