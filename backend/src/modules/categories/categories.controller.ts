import { Controller, Get, Header } from '@nestjs/common';
import { RateLimit } from '../rate-limit/rate-limit.guard';
import { Public } from '../auth/auth.decorators';
import {
  CategoriesService,
  toVendorCategoryDto,
  type VendorCategoryDto,
} from './categories.service';

/** Public category list (guests can browse; reused by M12). */
@Controller('vendor-categories')
export class CategoriesController {
  constructor(private readonly categories: CategoriesService) {}

  @Get()
  @Public()
  @RateLimit({ name: 'categories-read', limit: 120, windowSeconds: 60 })
  @Header('Cache-Control', 'public, max-age=300')
  async list(): Promise<VendorCategoryDto[]> {
    return (await this.categories.published()).map(toVendorCategoryDto);
  }
}
