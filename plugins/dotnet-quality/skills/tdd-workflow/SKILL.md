---
name: tdd-workflow
description: Apply when implementing new features or fixing bugs. Ensures tests are written first following project patterns.
user-invocable: false
---

# TDD Workflow

When implementing features or fixing bugs, follow test-driven development.

## Backend (.NET)

1. **Create failing test** in the appropriate test project
2. **Use isolation patterns**:
   - Generate unique identifiers for test isolation
   - Use unique database schemas per test when applicable
3. **Run test**: `dotnet test --filter "TestClass"`
4. **Implement** until green
5. **Refactor** if needed

### Finding Test Projects

Test projects typically follow the convention `*.Tests` or `*.UnitTests`:
```bash
find . -name "*.Tests.csproj" -o -name "*.UnitTests.csproj"
```

## Frontend (Jest)

1. **Create test** in `__tests__/` directory or as `.test.ts` file
2. **Run watch mode**: `yarn test:watch` or `npm test -- --watch`
3. **Implement** until green
4. **Use Testing Library** patterns for component tests

### Example Structure
```typescript
import { render, screen } from '@testing-library/react';
import { MyComponent } from '../MyComponent';

describe('MyComponent', () => {
  it('should render correctly', () => {
    render(<MyComponent />);
    expect(screen.getByText('Expected')).toBeInTheDocument();
  });
});
```

## E2E (Playwright)

1. **Add test** in the Playwright test directory
2. **Use Page Object Model** for maintainability
3. **Debug with UI mode**: `npx playwright test --ui`

### Page Object Pattern
```typescript
// pages/MyPage.ts
export class MyPage extends BasePage {
  async navigate() { await this.page.goto('/my-route'); }
}

// tests/my.spec.ts
test('should work', async ({ myPage }) => {
  await myPage.navigate();
});
```

## Red-Green-Refactor Cycle

1. **RED**: Write a failing test that describes the expected behavior
2. **GREEN**: Write minimal code to make the test pass
3. **REFACTOR**: Improve code quality while keeping tests green

Run tests after each change to maintain confidence.
