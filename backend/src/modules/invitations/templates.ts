/**
 * Invitation template catalogue (M19 answer 3). Data only: adding a template
 * here makes it available to the app and the guest page without screen
 * changes. The user will plan the full set later (GI-36).
 */
export interface InvitationTemplate {
  code: string;
  name: string;
  /** Hex colours. */
  background: string;
  surface: string;
  text: string;
  accent: string;
  headingFont: 'serif' | 'sans' | 'script';
  ornament: 'none' | 'floral' | 'diya' | 'stars' | 'lines';
}

export const INVITATION_TEMPLATES: readonly InvitationTemplate[] = [
  {
    code: 'classic',
    name: 'Classic',
    background: '#FBF6EE',
    surface: '#FFFFFF',
    text: '#3A2E2A',
    accent: '#B08D57',
    headingFont: 'serif',
    ornament: 'lines',
  },
  {
    code: 'floral',
    name: 'Floral',
    background: '#FFF1F3',
    surface: '#FFFFFF',
    text: '#4A2B33',
    accent: '#D9577A',
    headingFont: 'script',
    ornament: 'floral',
  },
  {
    code: 'minimal',
    name: 'Minimal',
    background: '#F5F5F5',
    surface: '#FFFFFF',
    text: '#1F1F1F',
    accent: '#1F1F1F',
    headingFont: 'sans',
    ornament: 'none',
  },
  {
    code: 'festive',
    name: 'Festive',
    background: '#7A1E1E',
    surface: '#8E2A20',
    text: '#FFF4D6',
    accent: '#F2B705',
    headingFont: 'serif',
    ornament: 'diya',
  },
  {
    code: 'royal',
    name: 'Royal',
    background: '#1C1B3A',
    surface: '#26254D',
    text: '#F3EBD3',
    accent: '#D4AF37',
    headingFont: 'serif',
    ornament: 'stars',
  },
  {
    code: 'pastel',
    name: 'Pastel',
    background: '#EEF6F3',
    surface: '#FFFFFF',
    text: '#2D3B36',
    accent: '#6BAA94',
    headingFont: 'sans',
    ornament: 'floral',
  },
];

export function templateByCode(code: string): InvitationTemplate | undefined {
  return INVITATION_TEMPLATES.find((t) => t.code === code);
}
