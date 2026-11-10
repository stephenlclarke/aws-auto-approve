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
        if (element.matches(':disabled') || element.readOnly || element.getAttribute('aria-disabled') === 'true'
            || element.closest('[aria-hidden="true"], [inert]') || style.visibility !== 'visible') return false;
        for (let parent = element; parent; parent = parent.parentElement) {
            if (getComputedStyle(parent).opacity === '0') return false;
        }
        const rect = element.getBoundingClientRect();
        const left = Math.max(0, rect.left), right = Math.min(innerWidth, rect.right);
        const top = Math.max(0, rect.top), bottom = Math.min(innerHeight, rect.bottom);
        if (right <= left || bottom <= top) return false;
        const hit = document.elementFromPoint((left + right) / 2, (top + bottom) / 2);
        return hit !== null && (hit === element || element.contains(hit));
    };
    const controls = [...document.querySelectorAll(
        'input:not([type="hidden"]), textarea, select, button, [role="button"], [contenteditable="true"], a[href], [role="link"]'
    )].filter(visible);
    const actionable = controls.some(element => {
        const type = (element.type || '').toLowerCase();
        if (type === 'checkbox') return element.required;
        if (element.isContentEditable || ['TEXTAREA', 'SELECT'].includes(element.tagName)
            || (element.tagName === 'INPUT' && !['submit', 'button', 'reset'].includes(type))) return true;
        if (element.tagName === 'A' || element.getAttribute('role') === 'link') {
            const label = (element.textContent || element.getAttribute('aria-label') || '').trim();
            return /\\b(?:sign\\s*in|log\\s*in|another account|different account|try again)\\b/i.test(label)
                || /^(?:allow|confirm(?: and continue)?|continue|next|retry)$/i.test(label);
        }
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
