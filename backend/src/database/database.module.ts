import { Global, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppConfigService } from '../config/app-config.service';
import { DatabaseHealth } from './database-health';
import { TypeOrmDatabaseHealth } from './typeorm-database-health';

/**
 * PostgreSQL via TypeORM (ADR-0006). Schema changes only through migrations:
 * synchronize and migrationsRun are always false.
 */
@Global()
@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      inject: [AppConfigService],
      useFactory: (config: AppConfigService) => ({
        type: 'postgres',
        url: config.databaseUrl,
        autoLoadEntities: true,
        synchronize: false,
        migrationsRun: false,
        manualInitialization: true,
        connectTimeoutMS: 5_000,
        extra: { max: 10, application_name: 'event-planner-api' },
      }),
    }),
  ],
  providers: [{ provide: DatabaseHealth, useClass: TypeOrmDatabaseHealth }],
  exports: [DatabaseHealth],
})
export class DatabaseModule {}
