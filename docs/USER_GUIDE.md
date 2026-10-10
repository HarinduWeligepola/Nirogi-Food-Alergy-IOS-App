# Nirogi — User Guide

**Nirogi (නිරෝගී, "healthy") reads food labels for you and tells you whether a
product is safe for *your* allergies.**

---

## Contents

1. [First launch](#1-first-launch)
2. [Scanning a label](#2-scanning-a-label)
3. [Understanding your result](#3-understanding-your-result)
4. [Managing your profile](#4-managing-your-profile)
5. [Your scan history](#5-your-scan-history)
6. [Places](#6-places)
7. [Changing the language](#7-changing-the-language)
8. [Troubleshooting](#8-troubleshooting)
9. [Safety](#9-safety)

---

## 1. First launch

<img src="screenshots/01-onboarding.png" width="220" align="right" alt="Welcome screen">

The first time you open Nirogi it takes you through three short screens.

**Welcome** explains what the app does: it photographs a label, reads the
ingredient list on your phone, and checks it against you. Nothing is uploaded.

**What should we watch for?** is where you pick your allergens. Allergens
common in Sri Lanka — coconut, cashew, Maldive fish, sesame — are listed first,
with everything else underneath. Tap any to select it. Pick as many as you need;
you can change them at any time.

Everything you select starts at **Moderate** severity. You can fine-tune each
one later on the Profile tab.

**Please read this** is the safety disclaimer. Nirogi helps you read labels, but
it is not medical advice. Read it, then tap **I understand — Start**.

<br clear="right">

---

## 2. Scanning a label

<img src="screenshots/04-scan.png" width="220" align="right" alt="Scan screen">

Open the **Scan** tab. You have three ways to give Nirogi a label:

| Option | When to use it |
|---|---|
| **Take Photo** | You have the packet in your hand. Only appears if your device has a camera. |
| **Choose Photo** | The label is already in your photo library. |
| **Try a Sample** | You want to see how the app works without a packet. |

### Getting a good scan

The app can only judge what it can read, so the photo matters:

- **Fill the frame** with the ingredients panel
- **Flatten curved packets** as much as you can
- **Avoid glare** and harsh shadows
- Point at the **English** text on a trilingual label

After you take the photo, Nirogi shows its progress: *Reading the label…* then
*Checking against your profile…* This usually takes a second or two.

<br clear="right">

### Sample labels

**Try a Sample** offers five bundled labels. These are real scans — each image
goes through the same text recognition as a photograph.

| Sample | What it shows you |
|---|---|
| Cream Biscuits | Hidden dairy and a peanut trace warning |
| Cashew Chocolate Bar | Cashew, milk solids and very high sugar |
| Chilli Sambol Paste | Umbalakada (Maldive fish) |
| Coconut Milk Powder | That "coconut milk" is not treated as dairy |
| Plain Rice Crackers | A clean label |

---

## 3. Understanding your result

<img src="screenshots/06-result-avoid.png" width="220" align="right" alt="An Avoid result">

### The verdict

| | Verdict | What it means |
|---|---|---|
| 🟢 | **Safe** | Nothing on this label conflicts with your profile |
| 🟡 | **Caution** | Something you should know about: a mild allergen, a trace warning, a diet clash, or a nutrient over your limit |
| 🔴 | **Avoid** | A moderate or severe allergen is actually listed |

Each verdict has its own **shape** as well as its own colour — a seal, a
triangle and an octagon — so you can tell them apart even if you find red and
green hard to distinguish.

### Why

This is the important part. Nirogi never just says "no". Under the verdict, each
reason shows you:

- **The allergen** it belongs to, e.g. Dairy
- **Contains** or **May contain** — whether it is a listed ingredient or only a
  cross-contamination warning
- **Found:** the exact words on the label, e.g. *"whey powder"*
- **Why** those two are connected, e.g. *"Whey powder is a form of dairy."*

If a word was matched by correcting a likely scan error, the app says so and
asks you to double-check the packet.

<br clear="right">

### Nutrition

If the label has a nutrition table, Nirogi reads it and shows the values per
100g. Anything above a limit you set turns amber.

### Ingredients read

Every ingredient the app found, in label order. Flagged ones are highlighted in
red, so you can match them against the packet in your hand.

### What the scan saw

Tap this to see the raw text the camera read. **Use this whenever a result looks
wrong** — it shows you exactly what the app saw, so you can tell the difference
between a bad photo and a bad verdict.

### Saving

Give the product a name and tap **Save scan** to keep it in your history.

---

## 4. Managing your profile

<img src="screenshots/09-profile.png" width="220" align="right" alt="Profile screen">

The **Profile** tab is what makes Nirogi yours.

### Allergens

Toggle any allergen on, and a severity picker appears:

| Severity | Meaning | Effect on the verdict |
|---|---|---|
| **Mild** | Mild discomfort, you prefer to avoid it | Caution |
| **Moderate** | Makes you unwell, you avoid it | Avoid |
| **Severe** | Dangerous reaction, never safe | Avoid, and trace warnings also become Avoid |

Under each allergen, the app tells you how many hidden names it recognises for
it — that is how it catches "casein" when you only said "dairy".

You can **search** allergens, and searching works on hidden names too. Type
"casein" and Dairy comes up.

### Diet

Vegetarian, vegan or halal. A diet clash always produces **Caution** rather than
Avoid, because it is a preference rather than a medical danger.

### Nutrition limits

Turn on any nutrient and drag the slider to set your maximum per 100g. Useful if
you are managing sugar or salt.

<br clear="right">

> **Changing your profile re-judges old scans.** Open any saved scan after
> changing your allergens and Nirogi re-checks it against your *current*
> profile, telling you if the verdict has changed since you saved it.

---

## 5. Your scan history

<img src="screenshots/08-home-history.png" width="220" align="right" alt="Home screen with history">

The **Home** tab shows what your labels are being checked against, then every
scan you have saved, newest first.

Each row shows the photo, the product name, which allergens were found, when you
scanned it, and the verdict.

- **Tap** a row to see the full result again
- **Search** by product name, ingredient or allergen
- **Press and hold** a row to delete it (you will be asked to confirm)

<br clear="right">

---

## 6. Places

Once you know a product is safe, it helps to remember where you bought it.

On the **Places** tab, tap the pin button while you are at the shop to tag your
most recent scan with your current location. Tagged scans then appear on the
map, colour-coded by verdict. Tap a pin to see which product it was.

Your location is only read at the moment you tap the button — the app never
tracks you — and it is never uploaded.

---

## 7. Changing the language

Nirogi speaks **English**, **Sinhala** and **Tamil**, and follows your phone's
language automatically.

To change it: **Settings → Nirogi → Language**.

> Nirogi reads the **English** text on a packet even when its own interface is
> in Sinhala or Tamil. The text recognition Apple provides cannot read Sinhala
> or Tamil script, so point the camera at the English ingredient list.

---

## 8. Troubleshooting

| Problem | What to do |
|---|---|
| **"No text was found on this label"** | Move closer, hold steady, and make sure the ingredient list is well lit and inside the frame. |
| **"No ingredient list was found"** | The app read some text but no ingredients. Make sure the ingredients panel itself is in the photo, not just the front of the packet. |
| **"This photo was hard to read"** | The scan worked but confidence was low, so an ingredient may have been missed. Retake it in better light. |
| **A result looks wrong** | Open **What the scan saw**. If the text is wrong, retake the photo. If the text is right but the verdict is wrong, check your Profile. |
| **Everything comes back Safe** | You probably have no allergens set. Open **Profile** and add them. |
| **An ingredient was flagged that shouldn't be** | Check **Found:** on the result — it shows the exact words matched. If it says "possible scan error", the photo likely misread a word. |
| **No camera button** | You are running in the Simulator, which has no camera. Use **Choose Photo** or **Try a Sample**. |

---

## 9. Safety

**Nirogi assists you in reading labels. It is not medical advice, and it is not
a substitute for reading the packet yourself.**

- Scanning can misread blurred, curved or poorly lit text
- Manufacturers change recipes without warning
- A "may contain" warning is the manufacturer's own hedge, not a guarantee
- For a severe allergy, always confirm by reading the packet

If you have a reaction, follow your doctor's advice and seek medical help.
