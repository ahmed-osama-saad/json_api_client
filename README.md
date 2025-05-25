# JSON:API Client Library for Dart/Flutter

A Dart/Flutter library for interacting with APIs that implement the [JSON:API specification](https://jsonapi.org/). This client simplifies data fetching, manipulation, and relationship management with JSON:API-compliant backends.

This library is inspired by [Coloquent](https://github.com/DavidDuwaer/Coloquent) and uses [JAPX](https://pub.dev/packages/japx) to flatten JSON:API's nested structure into a more manageable format for Dart objects.

> **Note**: This package is still under development and may undergo significant changes.

## Features

- **Fully Type-Safe**: Generic models with strong typing support
- **Relationship Management**: Easy handling of to-one and to-many relationships
- **Fluent Query Building**: Chainable methods for filters, includes, and field selection
- **Complete CRUD Operations**: Create, read, update, and delete resources
- **Authentication Support**: Multiple authentication methods including token, Google, and Apple Sign-In
- **Customizable Requests**: Set headers, query parameters, and more

## Getting Started

### Initialize the Client

```dart
void main() {
  JsonApiClient.init(
    'https://api.example.com',
    version: 'v1',
    languageCode: 'en',
    typesMap: {
      User: 'users',
      Post: 'posts',
      // Add all your model types here
    },
  );

  // Optional: Add persistent headers
  JsonApiClient.appendHeaders({
    'X-API-KEY': 'your-api-key',
  });
}
```

### Define Your Models

Models should extend `BaseModel<T>` and implement the JSON serialization:

```dart
@JsonSerializable()
class User extends BaseModel<User> {
  String? name;
  String? email;

  User({String? id, this.name, this.email}) : super(id: id);

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
```

### Create a Query Class

```dart
class UserQuery extends Query<User> {
  @override
  User instanceFromJson(Map<String, dynamic> json) => User.fromJson(json);
}
```

### Fetch Data

```dart
// Get a list of users
final users = await UserQuery().get();

// Get a single user
final user = await UserQuery().find(findId: '123');

// Get with filters
final filteredUsers = await UserQuery()
    .where('name', 'John')
    .get();

// Include relationships
final usersWithPosts = await UserQuery()
    .withRelations(['posts', 'profile'])
    .get();

// Select specific fields
final userNames = await UserQuery()
    .select(['name'], 'users')
    .get();
```

### Create and Update Resources

```dart
// Create a new user
final newUser = User(name: 'Jane', email: 'jane@example.com');
final createdUser = await UserQuery().create(newUser);

// Update a user
user.name = 'Jane Doe';
final updatedUser = await UserQuery().save(user);
```

### Managing Relationships

```dart
// Attach posts to a user
final user = await UserQuery().find(findId: '123');
await UserQuery().attach('123', [post1, post2], relationship: 'posts');

// Detach posts from a user
await UserQuery().detach('123', [post1, post2]);
```

### Authentication

```dart
// Login with email/password
final response = await ApiRequest.login('user@example.com', 'password');
JsonApiClient.userToken = response['token'];

// Login with Google
final googleResponse = await ApiRequest.loginWithGoogle();
JsonApiClient.userToken = googleResponse['token'];

// Login with Apple
final appleResponse = await ApiRequest.loginWithApple();
JsonApiClient.userToken = appleResponse['token'];
```

## Advanced Usage

### Custom Endpoints

```dart
class CustomUserQuery extends UserQuery {
  @override
  String generateEndpoint() => 'custom-users';
}
```

### Bulk Operations

```dart
// Bulk update
final updatedUsers = await UserQuery().bulkUpdate([user1, user2]);
```

### Custom Actions

```dart
// Perform a custom action on a resource
final result = await UserQuery().singularAction('verify-email');
```

## Error Handling

The library provides custom exceptions for different HTTP status codes:

- `UnAuthorizedException` (401)
- `ForbiddenException` (403)
- `ServerException` (Other errors)
- `LoginException` (Authentication errors)
