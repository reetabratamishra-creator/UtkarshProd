/**
 * Presentation helpers for the Campaign Management filter workspace.
 * These only format labels and compare filter values. They do not query or send.
 */

function toIsoDate(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

function parseIsoDate(isoDate) {
    if (!isoDate) {
        return null;
    }
    const parts = String(isoDate).split('-').map((part) => Number(part));
    if (parts.length !== 3 || parts.some((part) => Number.isNaN(part))) {
        return null;
    }
    return new Date(parts[0], parts[1] - 1, parts[2]);
}

export function presetRange(preset) {
    const today = new Date();
    const end = toIsoDate(today);

    if (preset === '7' || preset === '30') {
        const start = new Date(today);
        start.setDate(today.getDate() - (preset === '7' ? 6 : 29));
        return { fromDate: toIsoDate(start), toDate: end };
    }

    if (preset === 'quarter') {
        const quarterStartMonth = Math.floor(today.getMonth() / 3) * 3;
        const quarterEnd = new Date(today.getFullYear(), quarterStartMonth + 3, 0);
        return {
            fromDate: toIsoDate(new Date(today.getFullYear(), quarterStartMonth, 1)),
            toDate: toIsoDate(quarterEnd)
        };
    }

    return null;
}

export function detectDatePreset(fromDate, toDate) {
    if (!fromDate && !toDate) {
        return '';
    }
    for (const preset of ['7', '30', 'quarter']) {
        const range = presetRange(preset);
        if (range.fromDate === fromDate && range.toDate === toDate) {
            return preset;
        }
    }
    return 'custom';
}

export function formatShortDate(isoDate) {
    const date = parseIsoDate(isoDate);
    if (!date) {
        return '';
    }
    return date.toLocaleDateString('en-GB', { day: 'numeric', month: 'short' });
}

export function dateChipLabel(fromDate, toDate) {
    const preset = detectDatePreset(fromDate, toDate);
    if (preset === '7') {
        return 'Last 7 days';
    }
    if (preset === '30') {
        return 'Last 30 days';
    }
    if (preset === 'quarter') {
        return 'This quarter';
    }
    const fromLabel = formatShortDate(fromDate);
    const toLabel = formatShortDate(toDate);
    if (fromLabel && toLabel) {
        return `${fromLabel} – ${toLabel}`;
    }
    if (fromLabel) {
        return `From ${fromLabel}`;
    }
    if (toLabel) {
        return `To ${toLabel}`;
    }
    return '';
}

export function optionLabels(values, options) {
    const labelsByValue = new Map(
        (options || []).map((option) => [option.value, option.label])
    );
    return (values || [])
        .filter((value) => value)
        .map((value) => labelsByValue.get(value) || value);
}

export function listChipLabel(labels) {
    const clean = (labels || []).filter((label) => label);
    if (clean.length === 0) {
        return '';
    }
    if (clean.length === 1) {
        return clean[0];
    }
    if (clean.length === 2) {
        return `${clean[0]}, ${clean[1]}`;
    }
    return `${clean[0]} +${clean.length - 1}`;
}

function normalizeValue(value) {
    if (Array.isArray(value)) {
        return [...value]
            .map((item) => (item == null ? '' : String(item)))
            .filter((item) => item !== '')
            .sort();
    }
    return value == null ? '' : String(value);
}

export function changedFieldCount(current, applied) {
    if (!applied) {
        return 0;
    }
    const keys = new Set([...Object.keys(current || {}), ...Object.keys(applied)]);
    let count = 0;
    keys.forEach((key) => {
        if (
            JSON.stringify(normalizeValue(current ? current[key] : '')) !==
            JSON.stringify(normalizeValue(applied[key]))
        ) {
            count += 1;
        }
    });
    return count;
}

export function filtersMatch(current, applied) {
    return changedFieldCount(current, applied) === 0;
}