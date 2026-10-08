import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import type { Repository } from 'typeorm';
import { VendorCategoryEntity } from './vendor-category.entity';

export interface VendorCategoryDto {
  id: string;
  name: string;
  slug: string;
  sortOrder: number;
}

@Injectable()
export class CategoriesService {
  constructor(
    @InjectRepository(VendorCategoryEntity)
    private readonly categories: Repository<VendorCategoryEntity>,
  ) {}

  /** Published categories in display order (marketplace visibility, §9). */
  async published(): Promise<VendorCategoryEntity[]> {
    return this.categories.find({
      where: { status: 'PUBLISHED' },
      order: { sortOrder: 'ASC', name: 'ASC' },
    });
  }
}

export function toVendorCategoryDto(
  category: VendorCategoryEntity,
): VendorCategoryDto {
  return {
    id: category.id,
    name: category.name,
    slug: category.slug,
    sortOrder: category.sortOrder,
  };
}
