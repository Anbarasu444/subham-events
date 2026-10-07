import {
  Body,
  Controller,
  INestApplication,
  Module,
  Post,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Type } from 'class-transformer';
import { IsString, ValidateNested } from 'class-validator';
import request from 'supertest';
import type { App } from 'supertest/types';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/app.setup';
import { MoneyDto } from '../src/common/money/money.dto';
import { DatabaseHealth } from '../src/database/database-health';
import { Public } from '../src/modules/auth/auth.decorators';
import { TokenVerifier } from '../src/modules/auth/token-verifier';
import { UsersService } from '../src/modules/users/users.service';
import { FakeTokenVerifier } from './fakes';

class FakeDatabaseHealth extends DatabaseHealth {
  up = true;
  isReady(): Promise<boolean> {
    return Promise.resolve(this.up);
  }
}

class EchoDto {
  @IsString()
  title: string;

  @ValidateNested()
  @Type(() => MoneyDto)
  budget: MoneyDto;
}

/** Test-only endpoint to exercise validation and the money DTO end to end. */
@Public()
@Controller('__test')
class EchoController {
  @Post('echo')
  echo(@Body() body: EchoDto) {
    return { title: body.title, budget: body.budget.toMoney() };
  }
}

@Module({ controllers: [EchoController] })
class EchoModule {}

describe('API foundation (e2e)', () => {
  let app: INestApplication<App>;
  const db = new FakeDatabaseHealth();

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule, EchoModule],
    })
      .overrideProvider(DatabaseHealth)
      .useValue(db)
      .overrideProvider(TokenVerifier)
      .useValue(new FakeTokenVerifier())
      .overrideProvider(UsersService)
      .useValue({ findAccessByFirebaseUid: () => Promise.resolve(null) })
      .compile();
    app = moduleRef.createNestApplication();
    configureApp(app);
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /api/v1/health/live returns the success envelope and a request id', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/health/live')
      .expect(200);
    expect(res.body).toEqual({
      data: { status: 'ok' },
      meta: { requestId: expect.any(String) },
    });
    expect(res.headers['x-request-id']).toBe(res.body.meta.requestId);
    expect(res.headers['x-powered-by']).toBeUndefined();
  });

  it('echoes a well-formed incoming X-Request-Id', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/health/live')
      .set('X-Request-Id', 'client-req-0001')
      .expect(200);
    expect(res.body.meta.requestId).toBe('client-req-0001');
  });

  it('GET /api/v1/health/ready returns 200 when the database is up', async () => {
    db.up = true;
    const res = await request(app.getHttpServer())
      .get('/api/v1/health/ready')
      .expect(200);
    expect(res.body.data).toEqual({ status: 'ok', checks: { database: 'up' } });
  });

  it('GET /api/v1/health/ready returns 503 SERVICE_UNAVAILABLE when the database is down', async () => {
    db.up = false;
    const res = await request(app.getHttpServer())
      .get('/api/v1/health/ready')
      .expect(503);
    expect(res.body.error).toMatchObject({
      code: 'SERVICE_UNAVAILABLE',
      details: [],
      requestId: expect.any(String),
    });
    db.up = true;
  });

  it('unknown routes return the 404 error envelope', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/does-not-exist')
      .expect(404);
    expect(res.body.error).toMatchObject({
      code: 'NOT_FOUND',
      requestId: expect.any(String),
    });
  });

  it('validation failures return 422 with field details', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/__test/echo')
      .send({
        title: 'Wedding',
        budget: { amount: 10.1, currency: 'INR' },
        extra: 1,
      })
      .expect(422);
    expect(res.body.error.code).toBe('VALIDATION_FAILED');
    const fields = (res.body.error.details as { field: string }[]).map(
      (d) => d.field,
    );
    expect(fields).toEqual(expect.arrayContaining(['extra', 'budget.amount']));
  });

  it('accepts decimal-rupee money and returns it unchanged', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/__test/echo')
      .send({
        title: 'Wedding',
        budget: { amount: '40000.10', currency: 'INR' },
      })
      .expect(201);
    expect(res.body.data).toEqual({
      title: 'Wedding',
      budget: { amount: '40000.10', currency: 'INR' },
    });
  });

  it('malformed JSON returns 400 BAD_REQUEST', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/__test/echo')
      .set('Content-Type', 'application/json')
      .send('{"title":')
      .expect(400);
    expect(res.body.error.code).toBe('BAD_REQUEST');
  });

  it('bodies over 1 MB return 413 PAYLOAD_TOO_LARGE', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/__test/echo')
      .set('Content-Type', 'application/json')
      .send(JSON.stringify({ title: 'x'.repeat(1_100_000) }))
      .expect(413);
    expect(res.body.error.code).toBe('PAYLOAD_TOO_LARGE');
  });

  it('protected routes require a token (global guard)', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/me')
      .expect(401);
    expect(res.body.error.code).toBe('AUTH_REQUIRED');
  });

  it('maps an expired token to AUTH_TOKEN_EXPIRED', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/me')
      .set('Authorization', 'Bearer fail:EXPIRED')
      .expect(401);
    expect(res.body.error.code).toBe('AUTH_TOKEN_EXPIRED');
  });
});
