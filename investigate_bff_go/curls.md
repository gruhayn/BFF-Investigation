# API Test Curls

## Health Check

```bash
curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/health
```

## Customers

### All customers
```bash
curl -s 'http://localhost:8080/customers' | python3 -m json.tool
```

### Filter by ID with all includes
```bash
curl -s 'http://localhost:8080/customers?filter.id=c1&include=addresses,bankAccounts,transactions,contacts' | python3 -m json.tool
```

### Search by name
```bash
curl -s 'http://localhost:8080/customers?filter.name=john' | python3 -m json.tool
```

### Search by email
```bash
curl -s 'http://localhost:8080/customers?filter.email=alice' | python3 -m json.tool
```

### Pagination
```bash
curl -s 'http://localhost:8080/customers?page.offset=2&page.limit=2' | python3 -m json.tool
```

### Only addresses
```bash
curl -s 'http://localhost:8080/customers?filter.id=c1&include=addresses' | python3 -m json.tool
```

### Only bank accounts with transactions
```bash
curl -s 'http://localhost:8080/customers?filter.id=c1&include=bankAccounts,transactions' | python3 -m json.tool
```

## Accounts

### All accounts
```bash
curl -s 'http://localhost:8080/accounts' | python3 -m json.tool
```

### Filter by currency with includes
```bash
curl -s 'http://localhost:8080/accounts?filter.currency=USD&include=holder,transactions' | python3 -m json.tool
```

### Filter by bank name
```bash
curl -s 'http://localhost:8080/accounts?filter.bankName=Euro%20Bank&include=holder' | python3 -m json.tool
```

### Pagination
```bash
curl -s 'http://localhost:8080/accounts?page.offset=0&page.limit=3&include=holder' | python3 -m json.tool
```

## Customer Summary (multiple concurrent clients)

### Summary for c1
```bash
curl -s 'http://localhost:8080/customer-summary?id=c1' | python3 -m json.tool
```

### Summary for c5
```bash
curl -s 'http://localhost:8080/customer-summary?id=c5' | python3 -m json.tool
```

### Not found
```bash
curl -s 'http://localhost:8080/customer-summary?id=c999' | python3 -m json.tool
```

### Missing id param
```bash
curl -s 'http://localhost:8080/customer-summary' | python3 -m json.tool
```

## Timing (async proof)

### Customer summary with timing
```bash
curl -s -w '\n--- Total: %{time_total}s ---\n' 'http://localhost:8080/customer-summary?id=c1' > /dev/null
```

### Customers with timing
```bash
curl -s -w '\n--- Total: %{time_total}s ---\n' 'http://localhost:8080/customers?filter.id=c1&include=addresses,bankAccounts,transactions,contacts' > /dev/null
```
