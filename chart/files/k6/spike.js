import http from "k6/http";
import { check, sleep } from "k6";

const targetUrl = __ENV.TARGET_URL || "http://hello-api-staging-hello-api";

export const options = {
  stages: [
    { duration: "1m", target: 50 },
    { duration: "1m", target: 200 },
    { duration: "2m", target: 200 },
    { duration: "1m", target: 0 },
  ],
  thresholds: {
    http_req_failed: ["rate<0.05"],
    http_req_duration: ["p(95)<1000"],
  },
};

export default function () {
  const response = http.get(`${targetUrl}/work`, { tags: { profile: "spike" } });

  check(response, {
    "work returned 200": (result) => result.status === 200,
  });

  sleep(0.01);
}
