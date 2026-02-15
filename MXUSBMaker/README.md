### 1. Build the USB with encrypted persistence

Do this from your already‑installed MX system.

1. **Open:** `MX Tools → MX Live USB Maker`.
2. **Source:**
   - Either your **MX ISO**, or  
   - **Running system** if you want to clone your current setup.
3. **Target:** select your USB drive (this will be wiped).
4. **Mode:** choose **Full‑featured** (not Image mode).
5. Tick **“Enable persistence”**.
6. When asked about persistence type, choose **root persistence** (you can leave home off if you don’t care about it).
7. When asked about encryption, choose **Encrypt persistence** and set a passphrase.
8. Let it finish writing.

That gives you a Live USB with an encrypted root persistence file/partition.

---

### 2. First boot: pick the correct persistence mode

1. Boot from the USB.
2. At the **MX boot menu**, look for the **Persistence** options (often via `F5` or an “Advanced options” entry—watch the hints at the bottom of the screen).
3. In the **root persistence** choices, select:

   **`persist_root`**

   This is the one that:
   - Uses root persistence
   - Does **not** autosave
   - Supports “save at shutdown” behavior

4. If it asks which persistence file to use, pick the **encrypted** one and enter your passphrase.
5. Boot into the live system.

---

### 3. Configure “ask at shutdown” behavior inside MX

Once you’re in the live session:

1. Open **MX Tools → Live USB Persistence**.
2. In that tool, confirm:
   - **Root persistence:** enabled (it should show your encrypted persistence).
   - **Home persistence:** optional (on or off as you prefer).
3. Look for the **save behavior** options—wording varies slightly by version, but you want the one that means:

   - **“Ask at shutdown whether to save changes”**  
   or  
   - **“Save only at shutdown (with prompt)”**

4. Make sure:
   - **Autosave / save periodically:** **disabled**  
   - **Ask at shutdown / save on exit with prompt:** **enabled**

Apply/OK and close the tool.

---

### 4. Test that it behaves exactly how you want

1. While running from the USB, make a small change:
   - e.g. create a file on the desktop, change a panel setting, etc.
2. Choose **Shutdown** or **Reboot** from the menu.
3. You should now see a dialog along the lines of:

   > “Save root persistence changes?”  
   > Yes / No

4. If you click **Yes**:
   - Changes are written into the **encrypted** persistence.
5. If you click **No**:
   - Changes are discarded; next boot is as if you never made them.

That gives you:

- **Encrypted persistence**  
- **No autosave during the session**  
- **A prompt at shutdown asking whether to save changes**  

---

