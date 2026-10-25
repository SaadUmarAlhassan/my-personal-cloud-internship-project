import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  stages: [
    { duration: "1m", target: 20 }, // ramp up
    { duration: "3m", target: 60 }, // hold - this is where scaling fires
    { duration: "1m", target: 0 }, // ramp down
  ],
  thresholds: {
    http_req_failed: ["rate<0.01"], // under 1% errors
    http_req_duration: ["p(95)<800"], // 95% under 800ms
  },
};

export default function () {
  const url = __ENV.TARGET; // pass your ALB URL in
  const res = http.get(`${url}/api/tasks`);
  check(res, { "status 200": (r) => r.status === 200 });
  sleep(1);
}
