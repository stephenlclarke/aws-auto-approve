"use strict";
if (location.protocol !== "https:" || location.hostname !== settings.host) return "interactive";
const text = (document.body?.innerText || "").replace(/\s+/g, " ").trim();
const buttons = [...document.querySelectorAll('button, input[type="submit"]')]
    .filter(button => !button.disabled && button.getAttribute("aria-disabled") !== "true"
        && button.getClientRects().length > 0);
const label = button => (button.innerText || button.value || "").trim().toLowerCase();
const confirm = buttons.filter(button => ["confirm", "confirm and continue"].includes(label(button)));
if (confirm.length) {
    if (!settings.expectedCode) return "interactive";
    const codes = text.match(/\b[A-Z0-9]{4}-[A-Z0-9]{4}\b/g) || [];
    if (codes.length !== 1 || codes[0] !== settings.expectedCode) return "mismatch";
    return clickOnce(confirm);
}
const allow = buttons.filter(button => label(button) === "allow");
if (allow.length && /\bAWS\b/.test(text) && /\baccess\b/i.test(text)) return clickOnce(allow);
if (!buttons.length && /(?:request (?:has been|is) approved|successfully authorized|you can (?:now )?close (?:this|the) (?:window|tab)|you have successfully logged in)/i.test(text)) {
    return "complete";
}
return "interactive";

function clickOnce(matches) {
    if (matches.length !== 1) return "interactive";
    const button = matches[0];
    if (button.dataset.awsAutoApproveClicked) return "waiting";
    button.dataset.awsAutoApproveClicked = "true";
    button.click();
    return "clicked";
}
