import { Module } from '@nestjs/common';
import { CoreAuthModule } from '../../core/auth/auth.module';
import { CategoriesController } from './controllers/categories.controller';
import { FinishedProductsController } from './controllers/finished-products.controller';
import { PartiesController } from './controllers/parties.controller';
import { RawMaterialsController } from './controllers/raw-materials.controller';
import { UnitsController } from './controllers/units.controller';
import { VendorsController } from './controllers/vendors.controller';
import { CategoriesService } from './services/categories.service';
import { FinishedProductsService } from './services/finished-products.service';
import { PartiesService } from './services/parties.service';
import { RawMaterialsService } from './services/raw-materials.service';
import { UnitsService } from './services/units.service';
import { VendorsService } from './services/vendors.service';

@Module({
  imports: [CoreAuthModule],
  controllers: [
    CategoriesController,
    UnitsController,
    VendorsController,
    RawMaterialsController,
    FinishedProductsController,
    PartiesController,
  ],
  providers: [
    CategoriesService,
    UnitsService,
    VendorsService,
    RawMaterialsService,
    FinishedProductsService,
    PartiesService,
  ],
  exports: [
    CategoriesService,
    UnitsService,
    VendorsService,
    RawMaterialsService,
    FinishedProductsService,
    PartiesService,
  ],
})
export class MastersModule {}
