import type { ListingRow } from './listings.repository';
import { toListingCardDto } from './listings.service';

const row: ListingRow = {
  id: 'l1',
  title: 'Candid wedding photography',
  category_id: 'c1',
  category_name: 'Photography',
  category_slug: 'photography',
  vendor_id: 'v1',
  business_name: 'Candid Frames',
  city: 'Chennai',
  service_areas: ['Vellore'],
  starting_price_amount: '25000.00',
  currency: 'INR',
  rating_count: 0,
  rating_sum: 0,
  published_at: '2026-10-01T10:00:00.123456Z',
  rank: 0,
};

describe('toListingCardDto', () => {
  it('maps a row with exact money and millisecond time', () => {
    expect(toListingCardDto(row)).toMatchObject({
      startingPrice: { amount: '25000.00', currency: 'INR' },
      rating: { average: null, count: 0 },
      coverImageUrl: null,
      publishedAt: '2026-10-01T10:00:00.123Z',
    });
  });

  it('averages ratings to one decimal', () => {
    expect(
      toListingCardDto({ ...row, rating_count: 3, rating_sum: 13 }).rating,
    ).toEqual({ average: '4.3', count: 3 });
  });
});
