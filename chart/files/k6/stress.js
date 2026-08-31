import http from "k6/http";
import { check, sleep } from "k6";

const targetUrl = __ENV.TARGET_URL || "http://hello-api-staging-hello-api";

export const options = {
  stages: [
    { duration: "15s", target: 100 },
    { duration: "90s", target: 300 },
    { duration: "15s", target: 0 },
  ],
  thresholds: {
    http_req_failed: ["rate<0.25"],
    http_req_duration: ["p(95)<5000"],
  },
};

export default function () {
  const response = http.get(`${targetUrl}/work`, { tags: { profile: "stress" } });
  check(response, { "status is 200 or injected 503": (r) => r.status === 200 || r.status === 503 });
  sleep(0.01);
}
