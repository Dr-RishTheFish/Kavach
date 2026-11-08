import type { RiskAnalyzer } from './RiskAnalyzer.js';
import type { AnalyzeRequest, AnalyzerResult } from './types.js';

/**
 * Deterministic DEMO analyzer. Keyword rules are checked in order and the first match wins,
 * so higher-risk patterns take precedence over benign words. This is fixture matching for
 * the prototype, not fraud detection. It never fetches URLs and never echoes user text.
 */
interface Rule {
  id: string;
  matches: (text: string) => boolean;
  riskScore: number;
  summary: string;
  signals: string[];
  recommendedActions: string[];
}

const has = (re: RegExp) => (text: string) => re.test(text);
const URGENCY = /\b(urgent|urgently|immediately|right away|asap|now|in \w+ minutes)\b/;
const URGENCY_SIGNAL = 'The message pressures the recipient to act immediately.';

const RULES: Rule[] = [
  {
    id: 'one-time-code',
    matches: t => /\b(code|otp|one[- ]time|passcode|verification)\b/.test(t) && /\b(tell|share|send|read|give)\b/.test(t),
    riskScore: 95,
    summary: 'This description contains signs of a possible one-time-code phishing attempt.',
    signals: ['Someone asked for a one-time or verification code.'],
    recommendedActions: [
      'Do not share one-time codes with anyone who contacts you.',
      'If you already shared a code, contact the affected service using an independently verified number.',
    ],
  },
  {
    id: 'bank-impersonation',
    matches: t => /\b(bank|banking|financial)\b/.test(t) && /\b(transfer|wire|send money|move money|payment)\b/.test(t),
    riskScore: 92,
    summary: 'This description contains signs of a possible bank impersonation scam.',
    signals: ['The caller claimed to represent a financial institution.', 'The caller asked for a money transfer.'],
    recommendedActions: [
      'Do not transfer money or share a one-time code.',
      'Contact your bank using a phone number you independently verify.',
    ],
  },
  {
    id: 'package-fee-link',
    matches: t => /\b(deliver|delivery|delivered|package|parcel|shipment|courier)\b/.test(t) && /\b(fee|pay|link|click|https?)\b/.test(t),
    riskScore: 65,
    summary: 'This description resembles a common delivery-fee phishing pattern.',
    signals: ['A delivery problem is paired with a request to pay or follow a link.'],
    recommendedActions: [
      'Do not open the link or pay the fee.',
      'Check the delivery status directly on the carrier\'s official website or app.',
    ],
  },
  {
    id: 'unknown-callback',
    // An unfamiliar word alone is not enough: it must describe a number/caller/contact/sender.
    matches: has(
      /\b(unknown|unfamiliar|unrecognized|private|blocked) (number|caller|contact|sender|phone)\b|\bno caller id\b|\bcall (them|me|us) back\b|\bcallback\b/,
    ),
    riskScore: 35,
    summary: 'An unsolicited contact asked for a callback. This is not necessarily a scam, but review it carefully.',
    signals: ['The contact was unsolicited or from an unrecognized number.'],
    recommendedActions: [
      'Do not call back unfamiliar numbers in a hurry.',
      'If it claims to be an organization, look up its official number yourself.',
    ],
  },
  {
    id: 'benign-known-contact',
    matches: has(/\b(friend|family|lunch|dinner|plans|confirmed|appointment)\b/),
    riskScore: 10,
    summary: 'This description shows no common scam signals. A low score is not a safety guarantee.',
    signals: [],
    recommendedActions: ['Stay alert if the contact later asks for money, codes or personal details.'],
  },
];

const FALLBACK: Omit<Rule, 'id' | 'matches'> = {
  riskScore: 40,
  summary:
    'Simulated demo assessment: the mock analyzer did not recognize this pattern, so it cannot judge it. Review it carefully.',
  signals: [],
  recommendedActions: [
    'Do not share codes, passwords or payment details with unexpected contacts.',
    'Verify the sender through an official channel you look up yourself.',
  ],
};

export class MockRiskAnalyzer implements RiskAnalyzer {
  readonly provider = 'mock' as const;

  async analyze(request: AnalyzeRequest): Promise<AnalyzerResult> {
    const text = [request.content, request.context ?? ''].join(' ').toLowerCase();
    const rule = RULES.find(r => r.matches(text));
    const base = rule ?? FALLBACK;
    const signals = [...base.signals];
    if (rule && rule.riskScore >= 50 && URGENCY.test(text)) signals.push(URGENCY_SIGNAL);

    return {
      riskScore: base.riskScore,
      summary: base.summary,
      signals,
      recommendedActions: [...base.recommendedActions],
      source: 'mock',
      requiresHumanReview: rule === undefined,
    };
  }
}
