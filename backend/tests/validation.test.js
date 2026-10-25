'use strict';

const request = require('supertest');
const { app } = require('../src/app');
const { prisma } = require('../src/repositories/task.repository');

describe('Input Validation & Safe Error Responses', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  test('Registration rejects short password (<12 chars) with 400 VALIDATION_ERROR', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({
      email: `valid-${Date.now()}@example.test`,
      password: 'short',
    });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details.some((d) => d.field === 'password')).toBe(true);
  });

  test('Registration rejects invalid email format with 400', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({
      email: 'not-an-email',
      password: 'valid-long-password-1234',
    });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details.some((d) => d.field === 'email')).toBe(true);
  });

  test('Login fails with safe generic error on incorrect credentials', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({
      email: 'nonexistent@example.test',
      password: 'some-password-1234',
    });

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHENTICATED');
    expect(res.body.error.message).toBe('Invalid email or password.');
  });

  test('Task creation rejects empty title with 400', async () => {
    // Register user to get token
    const authRes = await request(app).post('/api/v1/auth/register').send({
      email: `task-val-${Date.now()}@example.test`,
      password: 'valid-password-1234',
    });

    const res = await request(app)
      .post('/api/v1/tasks')
      .set('Authorization', `Bearer ${authRes.body.accessToken}`)
      .send({ title: '   ' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  test('Task list rejects negative or out-of-bounds page numbers', async () => {
    const authRes = await request(app).post('/api/v1/auth/register').send({
      email: `page-val-${Date.now()}@example.test`,
      password: 'valid-password-1234',
    });

    const res = await request(app)
      .get('/api/v1/tasks?page=-5')
      .set('Authorization', `Bearer ${authRes.body.accessToken}`);

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });
});
