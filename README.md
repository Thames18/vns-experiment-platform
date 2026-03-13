# Low-Cost Vagus Nerve Stimulation Prototype

This project explores a low-cost, non-invasive approach to vagus nerve stimulation using smartphone vibration patterns and heart-rate monitoring. The goal is to study whether controlled vibration applied externally may produce short-term physiological responses measurable through heart-rate data.

## Project Overview

Traditional vagus nerve stimulation systems are expensive and often require specialized medical hardware. This project investigates a more accessible experimental setup using:

- A smartphone-based vibration controller
- Arduino-based heart-rate data collection
- The heart-rate sensor described in the project report
- Short-term heart-rate response measurements during baseline, stimulation, and recovery phases

This is an exploratory prototype and is **not intended for medical use or treatment**.

## What Has Been Done So Far

- Collected heart-rate data using Arduino and the selected sensor
- Built the initial Flutter Android application for vibration control
- Added Android vibration permission in the app manifest
- Defined the experimental protocol for baseline, stimulation, and recovery
- Outlined participant inclusion/exclusion criteria and session stop rules
- Designed the data collection and analysis plan for heart-rate response evaluation

## Current Status

The heart-rate data collection setup is working.

The smartphone vibration control feature is still being finalized and tested in the Flutter Android app.

## Planned Next Steps

- Finish implementing smartphone vibration patterns
- Validate vibration timing and device behavior on a physical Android phone
- Synchronize stimulation timing with heart-rate data collection
- Run multiple participant sessions
- Compare baseline, stimulation, and recovery measurements
- Analyze short-term heart-rate changes and session-to-session trends
- Document limitations, safety observations, and future improvements

## Experimental Design

### Participants
Inclusion:
- Ages 18–65
- No history of cardiovascular disease
- No diagnosed autonomic disorders
- Not taking medications that affect heart rate
- Able to remain still for 30+ minutes
- Able to provide informed consent

Exclusion:
- Pregnancy
- Pacemaker or implanted defibrillator
- History of seizures or epilepsy
- Current arrhythmia
- Recent neck/chest surgery
- Diagnosed panic or anxiety disorders
- Sensitivity to vibration
- Recent caffeine, nicotine, or exercise within 2–3 hours

### Session Structure
- Pre-session screening: 10 minutes
- Baseline measurement: 5 minutes
- Stimulation phase: 20 minutes
- Recovery phase: 5 minutes
- Post-session feedback: included after recovery

### Planned Vibration Conditions
- Control: no vibration
- Low frequency
- Medium frequency
- High frequency
- Pulsed vibration pattern

### Data to Collect
- Heart-rate measurements
- Time markers for baseline, stimulation, and recovery
- Subjective participant feedback
- Notes on discomfort, dizziness, relaxation, or adverse reactions

## Processing Pipeline

1. Collect heart-rate data from the Arduino sensor setup
2. Label data by session phase
3. Clean and segment recordings
4. Compare baseline vs stimulation vs recovery intervals
5. Summarize response trends across trials
6. Generate plots and tables for the final report/poster

## Tools and Technologies

- Flutter
- Android
- Arduino
- Heart-rate sensor
- Data logging and analysis tools

## Repository Structure

```text
lib/                 Flutter app source
android/             Android platform files
test/                Optional test files
README.md            Project description
pubspec.yaml         Flutter dependencies
