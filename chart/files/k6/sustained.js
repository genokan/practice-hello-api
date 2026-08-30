import http from "k6/http";
import { check, sleep } from "k6";

const targetUrl = __ENV.TARGET_URL || "http://hello-api-staging-hello-api";

export const options = {
  vus: 8,
  duration: "5m",
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<750"],
  },
};

export default function () {
  const response = http.get(`${targetUrl}/work`, { tags: { profile: "sustained" } });

  check(response, {
    "work returned 200": (result) => result.status === 200,
  });

  sleep(0.5);
}
