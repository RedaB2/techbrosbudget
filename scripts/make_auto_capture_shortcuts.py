#!/usr/bin/env python3
"""Generate and sign the pre-wired auto-capture shortcuts bundled in the app.

The auto-capture onboarding offers users a ready-made shortcut so the
Shortcuts automation setup needs zero variable wiring: the automation just
runs the imported shortcut, and the shortcut passes the trigger's content
into the app's App Intents.

Two shortcuts are produced:
- "Log My Purchase":  Wallet/Transaction trigger  -> LogWalletTransactionIntent
  (amount <- Shortcut Input's Amount, merchant <- Shortcut Input's Merchant)
- "Log Bank Alert":   Notification trigger (iOS 27) -> LogTransactionNotificationIntent
  (notificationTitle <- Title, notificationBody <- Body)

iOS refuses to import unsigned shortcut files, so each plist is signed with
`shortcuts sign --mode anyone` (requires macOS with Shortcuts, signed into
iCloud). Run from the repo root:

    python3 scripts/make_auto_capture_shortcuts.py

Output lands in techbrosbudget/ so the synchronized Xcode group picks the
signed files up as bundle resources.
"""

import plistlib
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

BUNDLE_ID = "reda.techbrosbudget"
REPO_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = REPO_ROOT / "techbrosbudget"

# The broad standard input-class list every shared shortcut carries; the
# automation trigger hands its content to the shortcut regardless.
INPUT_CLASSES = [
    "WFAppContentItem", "WFAppStoreAppContentItem", "WFArticleContentItem",
    "WFContactContentItem", "WFDateContentItem", "WFEmailAddressContentItem",
    "WFFolderContentItem", "WFGenericFileContentItem", "WFImageContentItem",
    "WFiTunesProductContentItem", "WFLocationContentItem",
    "WFDCMapsLinkContentItem", "WFAVAssetContentItem", "WFPDFContentItem",
    "WFPhoneNumberContentItem", "WFRichTextContentItem",
    "WFSafariWebPageContentItem", "WFStringContentItem", "WFURLContentItem",
]


def input_property_token(property_name: str) -> dict:
    """A parameter value referencing a property of Shortcut Input."""
    return {
        "Value": {
            "Type": "ExtensionInput",
            "Aggrandizements": [
                {
                    "Type": "WFPropertyVariableAggrandizement",
                    "PropertyName": property_name,
                }
            ],
        },
        "WFSerializationType": "WFTextTokenAttachment",
    }


def workflow(name: str, action_identifier: str, parameters: dict) -> dict:
    return {
        "WFQuickActionSurfaces": [],
        "WFWorkflowActions": [
            {
                "WFWorkflowActionIdentifier": action_identifier,
                "WFWorkflowActionParameters": {
                    "UUID": str(uuid.uuid4()).upper(),
                    **parameters,
                },
            }
        ],
        "WFWorkflowClientVersion": "4046.0.2.1.102",
        "WFWorkflowHasOutputFallback": False,
        "WFWorkflowHasShortcutInputVariables": True,
        "WFWorkflowIcon": {
            # 59771 renders as the lightning-bolt glyph; the color value is
            # the dark gray swatch so the icon matches the app's monochrome look.
            "WFWorkflowIconGlyphNumber": 59771,
            "WFWorkflowIconStartColor": -6115067,
        },
        "WFWorkflowImportQuestions": [],
        "WFWorkflowInputContentItemClasses": INPUT_CLASSES,
        "WFWorkflowMinimumClientVersion": 900,
        "WFWorkflowMinimumClientVersionString": "900",
        "WFWorkflowName": name,
        "WFWorkflowOutputContentItemClasses": [],
        "WFWorkflowTypes": ["WFWorkflowTypeShowInSearch"],
    }


SHORTCUTS = [
    (
        "Log My Purchase",
        "Log My Purchase.shortcut",
        workflow(
            "Log My Purchase",
            f"{BUNDLE_ID}.LogWalletTransactionIntent",
            {
                "amount": input_property_token("Amount"),
                "merchant": input_property_token("Merchant"),
            },
        ),
    ),
    (
        "Log Bank Alert",
        "Log Bank Alert.shortcut",
        workflow(
            "Log Bank Alert",
            f"{BUNDLE_ID}.LogTransactionNotificationIntent",
            {
                "notificationTitle": input_property_token("Title"),
                "notificationBody": input_property_token("Body"),
            },
        ),
    ),
]


def main() -> int:
    OUTPUT_DIR.mkdir(exist_ok=True)

    for name, filename, plist in SHORTCUTS:
        with tempfile.NamedTemporaryFile(suffix=".shortcut", delete=False) as tmp:
            plistlib.dump(plist, tmp, fmt=plistlib.FMT_BINARY)
            unsigned_path = Path(tmp.name)

        signed_path = OUTPUT_DIR / filename
        signed_path.unlink(missing_ok=True)

        result = subprocess.run(
            [
                "shortcuts", "sign",
                "--mode", "anyone",
                "--input", str(unsigned_path),
                "--output", str(signed_path),
            ],
            capture_output=True,
            text=True,
        )
        unsigned_path.unlink(missing_ok=True)

        if result.returncode != 0:
            print(f"FAILED to sign {name}: {result.stderr.strip()}", file=sys.stderr)
            return 1

        print(f"Signed {name} -> {signed_path} ({signed_path.stat().st_size} bytes)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
