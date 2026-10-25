'use strict';

const request = require('supertest');
const { app } = require('../src/app');
const { prisma } = require('../src/repositories/task.repository');

describe('Task Ownership & IDOR Protection', () => {
  let userA, userB;
  let taskA;

  beforeAll(async () => {
    // Register User A
    const resA = await request(app).post('/api/v1/auth/register').send({
      email: `user-a-${Date.now()}@example.test`,
      password: 'password-user-a-1234',
    });
    userA = resA.body;

    // Register User B
    const resB = await request(app).post('/api/v1/auth/register').send({
      email: `user-b-${Date.now()}@example.test`,
      password: 'password-user-b-1234',
    });
    userB = resB.body;

    // User A creates a task
    const taskRes = await request(app)
      .post('/api/v1/tasks')
      .set('Authorization', `Bearer ${userA.accessToken}`)
      .send({
        title: 'Secret Task of User A',
        description: 'Only User A should access this',
      });
    taskA = taskRes.body.item;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  test('User A can list their own tasks', async () => {
    const res = await request(app)
      .get('/api/v1/tasks')
      .set('Authorization', `Bearer ${userA.accessToken}`);

    expect(res.status).toBe(200);
    expect(res.body.items.some((t) => t.id === taskA.id)).toBe(true);
  });

  test('User B cannot see User A task in task list', async () => {
    const res = await request(app)
      .get('/api/v1/tasks')
      .set('Authorization', `Bearer ${userB.accessToken}`);

    expect(res.status).toBe(200);
    expect(res.body.items.some((t) => t.id === taskA.id)).toBe(false);
  });

  test('User B cannot update (PATCH) User A task -> returns 404 (IDOR prevented)', async () => {
    const res = await request(app)
      .patch(`/api/v1/tasks/${taskA.id}`)
      .set('Authorization', `Bearer ${userB.accessToken}`)
      .send({ title: 'Hacked Title by User B', completed: true });

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  test('User B cannot delete (DELETE) User A task -> returns 404 (IDOR prevented)', async () => {
    const res = await request(app)
      .delete(`/api/v1/tasks/${taskA.id}`)
      .set('Authorization', `Bearer ${userB.accessToken}`);

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  test('Unauthenticated request to tasks is rejected with 401', async () => {
    const res = await request(app).get('/api/v1/tasks');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHENTICATED');
  });

  test('Enforces pagination bounds on task list', async () => {
    const res = await request(app)
      .get('/api/v1/tasks?page=1&limit=50')
      .set('Authorization', `Bearer ${userA.accessToken}`);

    expect(res.status).toBe(200);
    expect(res.body.page).toBe(1);
    expect(res.body.limit).toBe(50);
  });
});
