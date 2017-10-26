describe('utility', function(){
  describe('range', function() {
    it('returns range', function() {
      expect(utility.range(3)).toEqual([0,1,2]);
    });
    it('can optionally exclude numbers', function() {
      expect(utility.range(4, [1,2])).toEqual([0,3]);
    });
  });
  describe('RelationshipDetails', function(){
    it('returns an nested array', function(){
      utility.range(13, [7]).slice(1).forEach( i => {
	var details = utility.relationshipDetails(i);
	expect(details).toBeArray();
	details.forEach( x => expect(x).toBeArray());
	details.forEach( detail => {
	  expect(detail.length).toEqual(3);
	  detail.forEach( x => expect(x).toBeString());
	});
      });
    });
    it('throws errors if not between 1-12 and not 7', function(){
      utility.range(13, [0, 7]).forEach( i => {
	expect(() => utility.relationshipDetails(i)).not.toThrow(Error);
      });
      expect(() => utility.relationshipDetails(7)).toThrow('Lobbying relationships are not currently supposed by the bulk add tool');
      var invalidMsg = "Invalid relationship category. It must be a number between 1 and 12";
      expect(() => utility.relationshipDetails(0)).toThrow(invalidMsg);
      expect(() => utility.relationshipDetails(13)).toThrow(invalidMsg);
    });
  });

  describe('validDate', function() {
    it('works with good dates', function() {
      ['2016-01-01', '1992-12-03'].map(utility.validDate).forEach( d => expect(d).toBeTrue() );
    });

    it('works with bad dates', function() {
      ['tuesday', '20000-01-01', '1888-01', '1999-13-02', '2000-01-50']
	.map(utility.validDate).forEach( d => expect(d).toBeFalse() );
    });
  });

  describe('validURL', function(){
    it('accepts simple urls', function(){
      expect(utility.validURL('https://simple.url')).toBeTrue();
    });

    it('rejects bad urls', function(){
      expect(utility.validURL('/not/a/url')).toBeFalse();
    });
  });

  describe('object utilities', () => {

    const obj = { a: 1, b: 2};
    const nestedObj = { a: { b: 2, c: 3 } };
    
    describe('#get', () => {
      it('reads an arbitrary key from an object', () => {
        expect(utility.get(obj, 'a')).toEqual(1);
      });

      it('handles non-existent properties', () => {
        expect(utility.get(obj, "foo")).toEqual(undefined);
      });

      it('handles null objects', () => {
        expect(utility.get(null, "foo")).toEqual(null);
      });

      it('handles undefined objects', () => {
        expect(utility.get(undefined, "foo")).toEqual(undefined);
      });
    });

    describe('#getIn', () => {

      it('reads values from a nested sequence of keys in an object', () => {
        expect(utility.getIn(nestedObj, ["a", "b"])).toEqual(2);
      });

      it('handles non-existent nested keys', () => {
        expect(utility.getIn(nestedObj, ["a", "foo"])).toEqual(undefined);
      });

      it('handles lookup sequences that are longer than depth of object tree', () => {
        expect(utility.getIn(nestedObj, ["a", "b", "d"])).toEqual(false);
      });
    });

    describe('#set', () => {
      it('sets the value for an arbitary key on an object', () => {
        expect(utility.set(obj, 'c', 3)).toEqual({ a: 1, b: 2, c: 3 });
      });

      it('does not mutate objects', () => {
        utility.set(obj, 'c', 3);
        expect(obj).toEqual({ a: 1, b: 2});
      });

      it('does not allow newly created entries to be mutated', () => {
        const _obj = utility.set(obj, 'c', 3);
        _obj.c = 4;
        expect(_obj.c).toEqual(3);
      });

      it('does allow newly created entries to be re-set', () => {
        const _obj = utility.set(obj, 'c', 3);
        const __obj = utility.set(_obj, 'c', 4);
        expect(__obj.c).toEqual(4);
      });
    });

    describe('#setIn', () => {

      it('sets the value for a nested key in an object', () => {
        expect(utility.setIn(nestedObj, ['a', 'b'], 4))
          .toEqual({ a: { b: 4, c: 3 } });
      });

      it('creates and sets the value for a nested key in an object', () => {
        expect(utility.setIn(nestedObj, ['a', 'd'], 4))
          .toEqual({ a: { b: 2, c: 3, d: 4 } });
      });

      it("handles paths longer than tree", () => {
        expect(utility.setIn(nestedObj, ["a", "d", "e"], 4))
          .toEqual({ a: { b: 2, c: 3, d: { e: 4 } } });
      });

      it('handles wierd paths', () => {
        expect(utility.setIn(nestedObj, ['a', 'b', 'c'], 4))
          .toEqual({ a: { b: { c: 4}, c: 3 } } );
      });
    });

    describe('#isEmpty', () => {
      it("discovers if an object is empty", () => {
        expect(utility.isEmpty(obj)).toEqual(false);
        expect(utility.isEmpty({})).toEqual(true);
      });

      it('discovers if an array is empty', () => {
        expect(utility.isEmpty([])).toEqual(true);
        expect(utility.isEmpty([1, 2])).toEqual(false);
      });
    });


    
    describe('#normalize', () => {

      it('transforms an array of resources into a lookup table of resources by id', () => {
        expect(utility.normalize(
          [
            { id: 'a', foo: 'bar' },
            { id: 'b', foo: 'bar' }
          ]
        )).toEqual(
          {
            a: { id: 'a', foo: 'bar' },
            b: { id: 'b', foo: 'bar' }
          }
        );
      });
    });
  });
});
