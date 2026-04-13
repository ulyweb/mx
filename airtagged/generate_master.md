>[!NOTE]
>## The Unified "Master" Script
>Save this as generate_master.sh:
---
```bash
#!/bin/bash# Combined VeraCrypt Outer Volume Master Generator

TARGET_DIR="$1"if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Please mount your outer volume and provide the path."
    echo "Usage: ./generate_master.sh /media/veracrypt1"
    exit 1fi
# Define the full folder and file structure
declare -A STRUCTURE
STRUCTURE=(
    # Estate & Finance
    ["Estate_Planning"]="Final_Will_and_Testament_2023.pdf Living_Trust_Agreement.pdf Power_of_Attorney_Draft.docx"
    ["Financial/Bonds"]="Series_I_Savings_Bonds_Log.xlsx Municipal_Bond_Holdings_Q4.pdf"
    ["Financial/Banking"]="Checking_Statement_Jan.pdf Savings_Account_Growth_Plan.xlsx Bank_Contact_List.txt"
    ["Crypto_Portfolio"]="Coinbase_Tax_Export_2023.csv Ledger_Setup_Instructions.pdf Trezor_Recovery_Guide.docx"
    ["Security"]="Bitwarden_Setup_Guide.pdf Emergency_Access_Instructions.docx Backup_Codes.txt"
    # General Archives
    ["Work_Archive"]="Project_Roadmap.pdf Meeting_Minutes_2022.docx Q3_Budget_Draft.xlsx"
    ["Personal_Backups"]="Resume_Updated.pdf Old_Tax_Scans_2021.zip Scan_ID_Card.jpg"
    ["Legal_Documents"]="Lease_Agreement_Signed.pdf Insurance_Policy_Home.pdf"
)

echo "🚀 Populating unified decoy archive in: $TARGET_DIR"
for DIR in "${!STRUCTURE[@]}"; do
    mkdir -p "$TARGET_DIR/$DIR"
    
    # Get the filenames for this specific directory
    FILES=${STRUCTURE[$DIR]}
    
    for FILE in $FILES; do
        FULL_PATH="$TARGET_DIR/$DIR/$FILE"
        echo "📄 Creating: $DIR/$FILE"
        
        # 1. Write a professional-looking header
        {
            echo "--- CONFIDENTIAL DOCUMENT ---"
            echo "Subject: ${FILE%.*}"
            echo "Security Class: Level 2 (Restricted)"
            echo "Date: $(date +'%Y-%m-%d')"
            echo "Note: Verified Backup Copy"
            echo "----------------------------"
        } > "$FULL_PATH"
        
        # 2. Append random data to simulate real file weight (100KB to 3MB)
        # This prevents the files from being suspiciously empty
        FILE_SIZE=$(( (RANDOM % 3000) + 150 ))
        head -c "${FILE_SIZE}K" </dev/urandom >> "$FULL_PATH" 2>/dev/null
    done
done

echo "✅ Done. Your outer volume now looks like a highly sensitive, legitimate archive."
```
## Quick Setup:

   1. Make it executable:
   
   chmod +x generate_master.sh
   
   2. Run it:
   
   ./generate_master.sh /path/to/your/mounted/usb
   
   
## One Final Tip for MX Linux Users:
Since you are on MX Linux, you can verify how this looks to others by using the Thunar file manager. Once the script finishes, the drive should look like a standard collection of "important life documents."
Do you want to add a section for scanned receipts or medical records to make the "master" profile even more realistic?

