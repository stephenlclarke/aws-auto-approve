import Foundation

public struct InteractionPrompt {
    private var candidateURL: URL?
    private var firstSeen: TimeInterval?

    public init() {}

    public mutating func reset() {
        candidateURL = nil
        firstSeen = nil
    }

    public mutating func shouldShow(url: URL?, needsInteraction: Bool, now: TimeInterval) -> Bool {
        guard let url, needsInteraction else {
            reset()
            return false
        }
        guard candidateURL == url, let firstSeen else {
            candidateURL = url
            self.firstSeen = now
            return false
        }
        return now - firstSeen >= 1
    }

    // Passive inspection only: do not read credential values or click provider controls.
    public static let scriptSource = """
    const visible = element => {
        const style = getComputedStyle(element);
        return !element.disabled && !element.readOnly && element.getAttribute('aria-disabled') !== 'true'
            && element.getAttribute('aria-hidden') !== 'true' && style.visibility !== 'hidden'
            && style.opacity !== '0' && element.getClientRects().length > 0;
    };
    const controls = [...document.querySelectorAll(
        'input:not([type="hidden"]), textarea, select, button, [role="button"], [contenteditable="true"]'
    )].filter(visible);
    const actionable = controls.some(element => {
        const type = (element.type || '').toLowerCase();
        if (['checkbox', 'radio'].includes(type)) return element.required;
        if (element.isContentEditable || ['TEXTAREA', 'SELECT'].includes(element.tagName)
            || (element.tagName === 'INPUT' && !['submit', 'button', 'reset'].includes(type))) return true;
        if (element.tagName === 'BUTTON' || element.getAttribute('role') === 'button'
            || ['submit', 'button'].includes(type)) {
            const label = (element.textContent || element.getAttribute('aria-label') || element.value || '').trim();
            return !/^(?:cancel|back|close)$/i.test(label);
        }
        return true;
    });
    return actionable || [...document.querySelectorAll('iframe')].some(frame => {
        const rect = frame.getBoundingClientRect();
        return visible(frame) && frame.src.startsWith('https:') && rect.width >= 200 && rect.height >= 80;
    });
    """
}
