# k6 Performance Tests

### Running Basic Load Test
```bash
k6 run basic-load-test.js
```

### Running Stress Test
```bash
k6 run stress-test.js
```

### Using JSON for Dynamic Config
```bash
k6 run --env base_url=http://localhost:3000 dynamic-test.js
```

### **`dynamic-test.js`** (Advanced, Uses External Configs)
   - Reads dynamic configuration from environment variables.

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export default function () {
    let res = http.get(`${BASE_URL}/api/users`);
    check(res, {
        'status is 200': (r) => r.status === 200,
    });
    sleep(1);
}
```