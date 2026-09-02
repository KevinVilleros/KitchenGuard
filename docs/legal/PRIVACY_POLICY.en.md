# Privacy Policy — CocinaP

**Last updated:** [DD/MM/YYYY]

---

## 1. Introduction

CocinaP ("we", "the app", "the Service") is a smart kitchen safety application that helps detect fire, smoke, and the presence of people, and to prevent risk situations while cooking.

This Privacy Policy explains what data we process, how we use it, and what rights you have as a user.

**Legal note:** This document is informational and for guidance. It is not legal advice. If your use of the app involves specific obligations in your country (for example, video-surveillance or data protection rules such as the GDPR in the European Union), we recommend consulting a legal professional.

**App publisher:**
- Name / Legal entity: [Legal company name or person]
- Contact email: [email address]
- Address: [postal address]
- Website: [website URL]

---

## 2. Core principle: local processing on your device

The design of CocinaP prioritizes your privacy. **Camera images are processed directly on your device** (on your phone or on the computer where the system is installed).

**We do not send, store, or transmit to our servers** any images, clips, videos, or data derived from detection (such as the presence of people). Unless otherwise stated in this policy, all video analysis is local.

You can review this technical implementation in the manual and project architecture (see `docs/ARCHITECTURE.md`).

---

## 3. What data and permissions the app uses

The app may request the following permissions and process the following data, only for the purposes described:

### 3.1 Camera permission
- **Purpose:** capture live video of the kitchen to analyze risk sources and the presence of people.
- **Note:** recording is local. Analyzed images are not uploaded to external servers unless you configure synchronization or notification services that require it (see Section 4).

### 3.2 Storage permission
- **Purpose:** store app configuration (preferences, camera URLs, detection settings) locally on your device.

### 3.3 Notification permission
- **Purpose:** show you local alerts (sound and vibration) when the app detects a risk situation, such as an unattended kitchen.
- These notifications are generated and displayed on your own device.

### 3.4 Configuration data
- The preferences you enter (e.g., monitoring duration, alert time, detection confidence, IP camera settings) are stored **locally** on your device.

### 3.5 Use of third-party cameras (IP cameras)
- The app can connect to a security camera that you own (IP camera) using a URL that you configure yourself. In this case, the app **only accesses the camera's video stream** to analyze it locally. The URL and credentials you enter are stored locally on your device.
- **User responsibility:** you are responsible for being authorized to connect to those cameras and for complying with applicable privacy and video-surveillance laws in your jurisdiction (e.g., informing people who may be captured, and not placing cameras in areas with a high expectation of privacy, such as bathrooms or bedrooms).

---

## 4. Person detection and images

The app uses artificial-intelligence/computer-vision models (e.g., a TFLite person-detection model) to determine whether a person is present in the camera's field of view, in order to alert you if the kitchen is left unattended.

- **Local processing:** the model runs on the device. Records of when a person is or is not detected are not stored or transmitted, except for the local alert history.
- **No profiling:** we do not use detection to build behavioral profiles, biometric identification, or individual tracking.
- **Alert history:** the app keeps a limited alert history, stored locally, to inform you of risk events.

---

## 5. Sharing data with third parties

**We do not sell or rent** your personal data.

The app does not transmit your configuration or analyzed images to CocinaP servers **unless you configure features that require explicit connectivity** (for example, connecting to the CocinaP server/companion that you install and control yourself).

### About push notifications (additional information)
If, in the future, remote push notifications are enabled (e.g., through a messaging provider such as Firebase Cloud Messaging), the only technical data needed to send them would be the device identifier, for the sole purpose of delivering the notification to you. We would not use these mechanisms to analyze or resell your data. Any activation of these features will be informed in this policy.

---

## 6. Data retention

- Configuration data is kept on your device until you delete it or uninstall the app.
- You can delete the alert history at any time from the app settings.
- For full deletion, you can uninstall the app. If you have synced with your own server, delete the data on that server and revoke the configured connections/cameras.

**Right to be forgotten:** you can request the deletion of any data that may be held by the publisher by writing to the contact email at the beginning of this policy.

---

## 7. Security

We adopt reasonable technical and organizational measures to protect locally processed data, including encryption of configuration where applicable and the use of authentication for the app's access to your cameras.

However, no digital transmission or storage is completely secure. We encourage you to protect access to your device.

---

## 8. Children's privacy

The app is intended for adults responsible for a household. We do not intentionally collect data from children. If you are a parent or guardian and believe a minor has provided data, please contact us so we can delete it.

---

## 9. Your rights

Depending on applicable law (especially the GDPR in the EU), you may exercise the following rights, to the extent applicable:

- **Access:** know what data we process.
- **Rectification:** correct inaccurate data.
- **Erasure / deletion:** request data deletion.
- **Objection / restriction of processing.**
- **Data portability.**
- **Withdraw consent** at any time.
- Lodge a **complaint** with your country's data protection authority.

To exercise these rights, write to the contact email at the beginning of this policy.

---

## 10. Changes to this policy

We may update this Privacy Policy to reflect changes to the app or to the law. When we do, we will update the "last updated" date at the top of this document and, where relevant, notify you within the app.

---

## 11. Contact

If you have questions about this Privacy Policy, how your data is processed, or regulatory compliance, you can contact us at:

- **Email:** [email address]
- **Address:** [postal address]
- **Suggested subject:** "Privacy / Data protection"

---

*CocinaP — smart safety for your kitchen.*