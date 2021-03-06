import 'package:test/test.dart';
import 'package:aqueduct/aqueduct.dart';
import '../model_graph.dart';
import '../../helpers.dart';

/*
  The more rigid tests on joining are covered by tiered_where, has_many and has_one tests.
  These just check to ensure that belongsTo joins are going to net out the same.
 */

void main() {
  List<RootObject> rootObjects;
  ManagedContext ctx;
  setUpAll(() async {
    ctx = await contextWithModels([
      RootObject,
      RootJoinObject,
      OtherRootObject,
      ChildObject,
      GrandChildObject
    ]);
    rootObjects = await populateModelGraph(ctx);
  });

  tearDownAll(() async {
    await ctx.persistentStore.close();
  });

  group("Assign non-join matchers to belongsToProperty", () {
    test("Can use whereRelatedByValue", () async {
      var q = new Query<ChildObject>()..where.parents = whereRelatedByValue(1);
      var results = await q.fetch();

      expect(results.length,
          rootObjects.firstWhere((r) => r.rid == 1).children.length);
      for (var child in rootObjects.first.children) {
        var matching = results.firstWhere((c) => c.cid == child.cid);
        expect(child.value1, matching.value1);
        expect(child.value2, matching.value2);
        expect(child.parents.rid, 1);
      }
    });

    test(
        "Can match on belongsTo relationship's primary key, does not cause join",
        () async {
      var q = new Query<ChildObject>()..where.parents.rid = whereEqualTo(1);
      var results = await q.fetch();

      expect(results.length,
          rootObjects.firstWhere((r) => r.rid == 1).children.length);
      for (var child in rootObjects.first.children) {
        var matching = results.firstWhere((c) => c.cid == child.cid);
        expect(child.value1, matching.value1);
        expect(child.value2, matching.value2);
        expect(child.parents.rid, 1);
      }
    });

    test("Can use whereNull", () async {
      var q = new Query<ChildObject>()..where.parents = whereNull;
      var results = await q.fetch();

      var childNotChildren =
          rootObjects.expand((r) => [r.child]).where((c) => c != null).toList();

      expect(results.length, childNotChildren.length);
      childNotChildren.forEach((c) {
        expect(results.firstWhere((resultChild) => c.cid == resultChild.cid),
            isNotNull);
      });

      q = new Query<ChildObject>()..where.parent = whereNull;
      results = await q.fetch();

      var childrenNotChild =
          rootObjects.expand((r) => r.children ?? []).toList();

      expect(results.length, childrenNotChild.length);
      childrenNotChild.forEach((c) {
        expect(results.firstWhere((resultChild) => c.cid == resultChild.cid),
            isNotNull);
      });
    });

    test("Can use whereNotNull", () async {
      var q = new Query<ChildObject>()..where.parents = whereNull;
      var results = await q.fetch();

      var childNotChildren =
          rootObjects.expand((r) => [r.child]).where((c) => c != null).toList();

      expect(results.length, childNotChildren.length);
      childNotChildren.forEach((c) {
        expect(results.firstWhere((resultChild) => c.cid == resultChild.cid),
            isNotNull);
      });

      q = new Query<ChildObject>()..where.parent = whereNull;
      results = await q.fetch();
      var childrenNotChild =
          rootObjects.expand((r) => r.children ?? []).toList();

      expect(results.length, childrenNotChild.length);
      childrenNotChild.forEach((c) {
        expect(results.firstWhere((resultChild) => c.cid == resultChild.cid),
            isNotNull);
      });
    });
  });

  test("Multiple joins from same table", () async {
    var q = new Query<ChildObject>()
      ..sortBy((c) => c.cid, QuerySortOrder.ascending)
      ..joinOne((c) => c.parent)
      ..joinOne((c) => c.parents);
    var results = await q.fetch();

    expect(
        results.map((c) => c.asMap()).toList(),
        equals([
          fullObjectMap(ChildObject, 1, and: {"parents": null, "parent": fullObjectMap(RootObject, 1)}),
          fullObjectMap(ChildObject, 2, and: {"parents": fullObjectMap(RootObject, 1), "parent": null}),
          fullObjectMap(ChildObject, 3, and: {"parents": fullObjectMap(RootObject, 1), "parent": null}),
          fullObjectMap(ChildObject, 4, and: {"parents": fullObjectMap(RootObject, 1), "parent": null}),
          fullObjectMap(ChildObject, 5, and: {"parents": fullObjectMap(RootObject, 1), "parent": null}),
          fullObjectMap(ChildObject, 6, and: {"parents": null, "parent": fullObjectMap(RootObject, 2)}),
          fullObjectMap(ChildObject, 7, and: {"parents": fullObjectMap(RootObject, 2), "parent": null}),
          fullObjectMap(ChildObject, 8, and: {"parents": null, "parent": fullObjectMap(RootObject, 3)}),
          fullObjectMap(ChildObject, 9, and: {"parents": fullObjectMap(RootObject, 4), "parent": null})
        ]));
  });

  group("Join on parent of hasMany relationship", () {
    test("Standard join", () async {
      var q = new Query<ChildObject>()..joinOne((c) => c.parents);
      var results = await q.fetch();

      expect(
          results.map((c) => c.asMap()).toList(),
          equals([
            fullObjectMap(ChildObject, 1, and: {
              "parents": null,
              "parent": {"rid": 1}
            }),
            fullObjectMap(ChildObject, 2,
                and: {"parents": fullObjectMap(RootObject, 1), "parent": null}),
            fullObjectMap(ChildObject, 3,
                and: {"parents": fullObjectMap(RootObject, 1), "parent": null}),
            fullObjectMap(ChildObject, 4,
                and: {"parents": fullObjectMap(RootObject, 1), "parent": null}),
            fullObjectMap(ChildObject, 5,
                and: {"parents": fullObjectMap(RootObject, 1), "parent": null}),
            fullObjectMap(ChildObject, 6, and: {
              "parents": null,
              "parent": {"rid": 2}
            }),
            fullObjectMap(ChildObject, 7,
                and: {"parents": fullObjectMap(RootObject, 2), "parent": null}),
            fullObjectMap(ChildObject, 8, and: {
              "parents": null,
              "parent": {"rid": 3}
            }),
            fullObjectMap(ChildObject, 9, and: {"parents": fullObjectMap(RootObject, 4), "parent": null})
          ]));
    });

    test("Nested join", () async {
      var q = new Query<GrandChildObject>();
      q.joinOne((c) => c.parents)..joinOne((c) => c.parents);
      var results = await q.fetch();

      expect(
          results.map((g) => g.asMap()).toList(),
          equals([
            fullObjectMap(GrandChildObject, 1, and: {
              "parents": null,
              "parent": {"cid": 1}
            }),
            fullObjectMap(GrandChildObject, 2, and: {
              "parent": null,
              "parents": fullObjectMap(ChildObject, 1, and: {
                "parents": null,
                "parent": {"rid": 1}
              })
            }),
            fullObjectMap(GrandChildObject, 3, and: {
              "parent": null,
              "parents": fullObjectMap(ChildObject, 1, and: {
                "parents": null,
                "parent": {"rid": 1}
              })
            }),
            fullObjectMap(GrandChildObject, 4, and: {
              "parents": null,
              "parent": {"cid": 2}
            }),
            fullObjectMap(GrandChildObject, 5, and: {
              "parent": null,
              "parents": fullObjectMap(ChildObject, 2,
                  and: {"parents": fullObjectMap(RootObject, 1), "parent": null})
            }),
            fullObjectMap(GrandChildObject, 6, and: {
              "parent": null,
              "parents": fullObjectMap(ChildObject, 2,
                  and: {"parents": fullObjectMap(RootObject, 1), "parent": null})
            }),
            fullObjectMap(GrandChildObject, 7, and: {
              "parents": null,
              "parent": {"cid": 3}
            }),
            fullObjectMap(GrandChildObject, 8, and: {
              "parent": null,
              "parents": fullObjectMap(ChildObject, 4,
                  and: {"parents": fullObjectMap(RootObject, 1), "parent": null})
            }),
          ]));
    });

    test("Bidirectional join", () async {
      var q = new Query<ChildObject>()
        ..sortBy((c) => c.cid, QuerySortOrder.ascending)
        ..joinMany((c) => c.grandChildren)
            .sortBy((g) => g.gid, QuerySortOrder.descending)
        ..joinOne((c) => c.parents);

      var results = await q.fetch();

      expect(
          results.map((c) => c.asMap()).toList(),
          equals([
            fullObjectMap(ChildObject, 1, and: {
              "parents": null,
              "parent": {"rid": 1},
              "grandChildren": [
                fullObjectMap(GrandChildObject, 3, and: {
                  "parents": {"cid": 1},
                  "parent": null
                }),
                fullObjectMap(GrandChildObject, 2, and: {
                  "parents": {"cid": 1},
                  "parent": null
                }),
              ]
            }),
            fullObjectMap(ChildObject, 2, and: {
              "parents": fullObjectMap(RootObject, 1),
              "parent": null,
              "grandChildren": [
                fullObjectMap(GrandChildObject, 6, and: {
                  "parents": {"cid": 2},
                  "parent": null
                }),
                fullObjectMap(GrandChildObject, 5, and: {
                  "parents": {"cid": 2},
                  "parent": null
                }),
              ]
            }),
            fullObjectMap(ChildObject, 3, and: {
              "parents": fullObjectMap(RootObject, 1),
              "parent": null,
              "grandChildren": []
            }),
            fullObjectMap(ChildObject, 4, and: {
              "parents": fullObjectMap(RootObject, 1),
              "parent": null,
              "grandChildren": [
                fullObjectMap(GrandChildObject, 8, and: {
                  "parents": {"cid": 4},
                  "parent": null
                }),
              ]
            }),
            fullObjectMap(ChildObject, 5, and: {
              "parents": fullObjectMap(RootObject, 1),
              "parent": null,
              "grandChildren": []
            }),
            fullObjectMap(ChildObject, 6, and: {
              "parents": null,
              "parent": {"rid": 2},
              "grandChildren": []
            }),
            fullObjectMap(ChildObject, 7, and: {
              "parents": fullObjectMap(RootObject, 2),
              "parent": null,
              "grandChildren": []
            }),
            fullObjectMap(ChildObject, 8, and: {
              "parents": null,
              "parent": {"rid": 3},
              "grandChildren": []
            }),
            fullObjectMap(ChildObject, 9, and: {
              "parents": fullObjectMap(RootObject, 4),
              "parent": null,
              "grandChildren": []
            })
          ]));
    });
  });

  group("Join on parent of hasOne relationship", () {
    test("Standard join", () async {
      var q = new Query<ChildObject>()
        ..sortBy((c) => c.cid, QuerySortOrder.ascending)
        ..joinOne((c) => c.parent);
      var results = await q.fetch();

      expect(
          results.map((c) => c.asMap()).toList(),
          equals([
            fullObjectMap(ChildObject, 1,
                and: {"parents": null, "parent": fullObjectMap(RootObject, 1)}),
            fullObjectMap(ChildObject, 2, and: {
              "parents": {"rid": 1},
              "parent": null
            }),
            fullObjectMap(ChildObject, 3, and: {
              "parents": {"rid": 1},
              "parent": null
            }),
            fullObjectMap(ChildObject, 4, and: {
              "parents": {"rid": 1},
              "parent": null
            }),
            fullObjectMap(ChildObject, 5, and: {
              "parents": {"rid": 1},
              "parent": null
            }),
            fullObjectMap(ChildObject, 6,
                and: {"parents": null, "parent": fullObjectMap(RootObject, 2)}),
            fullObjectMap(ChildObject, 7, and: {
              "parents": {"rid": 2},
              "parent": null
            }),
            fullObjectMap(ChildObject, 8,
                and: {"parents": null, "parent": fullObjectMap(RootObject, 3)}),
            fullObjectMap(ChildObject, 9, and: {
              "parents": {"rid": 4},
              "parent": null
            })
          ]));
    });

    test("Nested join", () async {
      var q = new Query<GrandChildObject>()
        ..sortBy((g) => g.gid, QuerySortOrder.ascending);

      q.joinOne((c) => c.parent)..joinOne((c) => c.parent);

      var results = await q.fetch();

      expect(
          results.map((g) => g.asMap()).toList(),
          equals([
            fullObjectMap(GrandChildObject, 1, and: {
              "parents": null,
              "parent": fullObjectMap(ChildObject, 1,
                  and: {"parents": null, "parent": fullObjectMap(RootObject, 1)})
            }),
            fullObjectMap(GrandChildObject, 2, and: {
              "parent": null,
              "parents": {"cid": 1}
            }),
            fullObjectMap(GrandChildObject, 3, and: {
              "parent": null,
              "parents": {"cid": 1}
            }),
            fullObjectMap(GrandChildObject, 4, and: {
              "parents": null,
              "parent": fullObjectMap(ChildObject, 2, and: {
                "parents": {"rid": 1},
                "parent": null
              })
            }),
            fullObjectMap(GrandChildObject, 5, and: {
              "parent": null,
              "parents": {"cid": 2}
            }),
            fullObjectMap(GrandChildObject, 6, and: {
              "parent": null,
              "parents": {"cid": 2}
            }),
            fullObjectMap(GrandChildObject, 7, and: {
              "parents": null,
              "parent": fullObjectMap(ChildObject, 3, and: {
                "parents": {"rid": 1},
                "parent": null
              })
            }),
            fullObjectMap(GrandChildObject, 8, and: {
              "parent": null,
              "parents": {"cid": 4}
            })
          ]));
    });
  });

  group("Implicit joins", () {
    test("Standard implicit join", () async {
      var q = new Query<ChildObject>()..where.parents.value1 = whereEqualTo(1);
      var results = await q.fetch();

      expect(
          results.map((c) => c.asMap()).toList(),
          equals([
            fullObjectMap(ChildObject, 2, and: {
              "parent": null,
              "parents": {"rid": 1}
            }),
            fullObjectMap(ChildObject, 3, and: {
              "parent": null,
              "parents": {"rid": 1}
            }),
            fullObjectMap(ChildObject, 4, and: {
              "parent": null,
              "parents": {"rid": 1}
            }),
            fullObjectMap(ChildObject, 5, and: {
              "parent": null,
              "parents": {"rid": 1}
            }),
          ]));
    });

    test("Nested implicit joins", () async {
      var q = new Query<GrandChildObject>()
        ..where.parents.parents.value1 = whereEqualTo(1)
        ..sortBy((g) => g.gid, QuerySortOrder.ascending);

      var results = await q.fetch();

      expect(
          results.map((c) => c.asMap()).toList(),
          equals([
            fullObjectMap(GrandChildObject, 5, and: {
              "parent": null,
              "parents": {"cid": 2}
            }),
            fullObjectMap(GrandChildObject, 6, and: {
              "parent": null,
              "parents": {"cid": 2}
            }),
            fullObjectMap(GrandChildObject, 8, and: {
              "parent": null,
              "parents": {"cid": 4}
            }),
          ]));

      q = new Query<GrandChildObject>()
        ..where.parents.parents = whereRelatedByValue(1)
        ..sortBy((g) => g.gid, QuerySortOrder.ascending);
      results = await q.fetch();

      expect(
          results.map((c) => c.asMap()).toList(),
          equals([
            fullObjectMap(GrandChildObject, 5, and: {
              "parent": null,
              "parents": {"cid": 2}
            }),
            fullObjectMap(GrandChildObject, 6, and: {
              "parent": null,
              "parents": {"cid": 2}
            }),
            fullObjectMap(GrandChildObject, 8, and: {
              "parent": null,
              "parents": {"cid": 4}
            }),
          ]));
    });

    test("Bidirectional implicit join", () async {
      var q = new Query<ChildObject>()
        ..where.parents.rid = whereEqualTo(1)
        ..where.grandChild = whereNotNull;
      var results = await q.fetch();
      expect(
          results.map((c) => c.asMap()).toList(),
          equals([
            fullObjectMap(ChildObject, 2, and: {
              "parent": null,
              "parents": {"rid": 1}
            }),
            fullObjectMap(ChildObject, 3, and: {
              "parent": null,
              "parents": {"rid": 1}
            }),
          ]));
    });
  });
}