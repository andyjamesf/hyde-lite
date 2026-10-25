pragma Singleton
import QtQuick
import Quickshell

// Turns what PAM says during an authentication (the lock screen, the polkit prompt) into one short
// line. The case that matters most: after several failed attempts pam_faillock locks the account
// for a few minutes and then refuses every password, the right one included, saying
// "The account is locked due to 3 failed logins. (10 minutes left to unlock)". Showing just "Wrong
// password" there makes it look as if the keyboard were broken.
Singleton {
    // `text`: PAM's messages of one attempt (several may be joined with spaces). Returns "" when
    // there is nothing worth showing.
    function friendly(text) {
        const t = String(text ?? "").replace(/\s+/g, " ").trim();
        if (t === "")
            return "";
        if (/account (is )?(temporarily |temporary )?locked|locked due to|too many (failed|authentication)/i.test(t)) {
            const minutes = /(\d+)\s*minutes?/i.exec(t);
            const seconds = /(\d+)\s*seconds?/i.exec(t);
            const wait = minutes ? `${minutes[1]} min` : seconds ? `${seconds[1]} s` : "";
            return wait !== "" ? `Account locked after failed attempts. Try again in ${wait}` : "Account locked after failed attempts. Try again later";
        }
        return t;
    }
}
