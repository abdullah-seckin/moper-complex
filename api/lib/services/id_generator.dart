import 'package:mongo_dart/mongo_dart.dart' as mongo;

String newId() => mongo.ObjectId().oid;
