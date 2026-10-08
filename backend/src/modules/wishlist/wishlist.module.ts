import { Module } from '@nestjs/common';
import { ListingsModule } from '../listings/listings.module';
import { WishlistController } from './wishlist.controller';
import { WishlistService } from './wishlist.service';

@Module({
  imports: [ListingsModule],
  controllers: [WishlistController],
  providers: [WishlistService],
})
export class WishlistModule {}
