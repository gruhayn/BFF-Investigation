import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE = __ENV.BASE_URL || 'http://localhost:8080';
const ENDPOINT = __ENV.ENDPOINT || '/customer-summary?id=c1';

export const options = {
  stages: [
    { duration: '5s', target: 10 },
    { duration: '5s', target: 500 },
    { duration: '10s', target: 500 },
    { duration: '5s', target: 10 },
    { duration: '5s', target: 0 },
  ],
};

export default function () {
  const res = http.get(`${BASE}${ENDPOINT}`);
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(0.1);
}
