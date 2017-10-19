describe('Bulk Table module', () => {


  const entities = {
    newEntity0: {
      id: 'newEntity0',
      name: "Lew Basnight",
      primary_ext: "Person",
      blurb: "Adjacent to the invisible"
    },
    newEntity1: {
      id: 'newEntity1',
      name: "Chums Of Chance",
      primary_ext: "Org",
      blurb: "Do not -- strictly speaking -- exist"
    }
  };

  // TODO: sure would be nice to import this from app code and have a single source of truth!
  const columns = [{
    label: 'Name',
    attr:  'name',
    input: 'text'
  },{
    label: 'Entity Type',
    attr:  'primary_ext',
    input: 'select'
  },{
    label: 'Description',
    attr:  'blurb',
    input: 'text'
  }];

  var ids = {
    uploadButton:    "bulk-add-upload-button",
    notifications: "bulk-add-notifications"
  };

  const csv =
        "name,primary_ext,blurb\n" +
        `${entities.newEntity0.name},${entities.newEntity0.primary_ext},${entities.newEntity0.blurb}\n` +
        `${entities.newEntity1.name},${entities.newEntity1.primary_ext},${entities.newEntity1.blurb}\n`;

  const testDom ='<div id="test-dom"></div>';
  
  const defaultState = {
    rootId:   "test-dom",
    resource: "entities",
    endpoint: "/lists/1/new_entities",
    title:    "Add entities to List of Biggest Jerks"
  };

  beforeEach(() => { $('body').append(testDom); });
  afterEach(() => { $('#test-dom').remove(); });

  describe('initialization', () => {

    beforeAll(() => bulkTable.init(defaultState));

    it('stores a reference to its root node', () => {
      expect(bulkTable.get('rootId')).toEqual('test-dom');
    });

    it('initializes an empty entites hash table', () =>{
      expect(bulkTable.get('entitiesById')).toEqual({});
    });

    it('initializes an empty entites rowIds array', () =>{
      expect(bulkTable.get('rowIds')).toEqual([]);
    });

    it('stores a title', () => {
      expect(bulkTable.get('title')).toEqual("Add entities to List of Biggest Jerks");
    });

    it('stores an endpoint', () => {
      expect(bulkTable.get('endpoint')).toEqual("/lists/1/new_entities");
    });

    describe('detecting upload support', () => {

      let browserCanOpenFilesSpy;

      describe("when browser can open files", () => {

        beforeEach(() => {
          browserCanOpenFilesSpy = spyOn(utility, 'browserCanOpenFiles').and.returnValue(true);
          bulkTable.init(defaultState);
        });

        it('shows an upload button', () => {
          expect($(`#${ids.uploadButton}`)).toExist();
        });
      });

      describe('when browser cannot open files', () => {

        beforeEach(() => {
          browserCanOpenFilesSpy = spyOn(utility, 'browserCanOpenFiles').and.returnValue(false);
          bulkTable.init(defaultState);
        });

        it('hides the upload button', () => {
          expect($(`#${ids.uploadButton}`)).not.toExist();
        });

        it('displays an error message', () => {
          expect($(`#${ids.notifications}`).html()).toMatch('Your browser');
        });
      });
    });
  });

  describe('uploading csv', () => {

    const file = new File([csv], "test.csv", {type: "text/csv"});
    let hasFileSpy, getFileSpy;

    beforeEach(done => {
      hasFileSpy = spyOn(bulkTable, 'hasFile').and.returnValue(true);
      getFileSpy = spyOn(bulkTable, 'getFile').and.returnValue(file);
      bulkTable.init(defaultState);
      $(`#${ids.uploadButton}`).change();
      setTimeout(done, 1); // wait for file to upload
    });

    it('stores entity data', () => {
      expect(bulkTable.get('entitiesById')).toEqual({
        newEntity0: entities['newEntity0'],
        newEntity1: entities['newEntity1']
      });
    });

    it('stores row ordering', () => {
      expect(bulkTable.get('rowIds')).toEqual(Object.keys(entities));
    });

    it('hides upload button', () => {
      expect($(`#${ids.uploadButton}`)).not.toExist();
    });
  });

  describe('matching', () => {
    // TODO: new batch endpoint would be nice...
    it('queries LS for pre-existing entities from TableData object');
    it('marks matched entities in TableData object');
    it('stores list of possible matches in TableData row');
    it('allows user to choose to use a matched entitiy or create new entity');

    describe('user chooses matched entity', () => {
      it('marks entity row as matched');
      it('overwrites user-submitted entity fields with matched fields');
      it('stores an id');
    });

    describe('user chooses user-submitted fields', () => {
      it('ignores matched existing entity fields');
    });
  });

  describe('validations', () => {
    // TODO: leave a seam here to extend for different pages...
    it('requires a primary extension be selected');
    it('requires an org name to be at least 1 character long');
    it('requires a person to have a first and last name');
  });

  describe('rendering table from store data', () => {

    describe('with no entities', () => {

      beforeEach(() => bulkTable.init(defaultState));

      it('does not show a table', () =>{
        expect($('#test-dom table#bulk-add-table')).not.toExist();
      });
    });

    describe('with no matches', () => {

      beforeEach(() => {
        bulkTable.init(Object.assign({}, defaultState, { entitiesById: entities }));
      });

      describe('bulk add table', () => {

        it('exists', () => {
          expect($('#test-dom table#bulk-add-table')).toExist();
        });

        it('has columns labeling entity fields', () => {
          const thTags = $('#bulk-add-table thead tr th').toArray();
          expect(thTags).toHaveLength(3);
          thTags.forEach((th, idx) => expect(th).toHaveText(columns[idx].label));
        });

        it('has rows showing values of entity fields', () => {
          const rows = $('#bulk-add-table tbody tr').toArray();
          expect(rows).toHaveLength(2);
          rows.forEach((row, idx) => {
            expect(row.textContent).toEqual( // row.textContent concatenates all cell text with no spaces
              columns.map(col => entities[`newEntity${idx}`][col.attr] ).join("")
            );
          });
        });
      });

      describe('making edits', () => {
        it('has inputs specific to each field');
        it('updates the store when input values change');
      });
    });

    describe('with matches', () => {
      it('prompts user to use match or create new entity');

      describe('user chooses matched entity', () => {
        it('marks rows with matched entities');
        it('blocks edits to matched entity fields');
      });
    });

    describe('with invalid fields', () => {
      it('marks invalid fields');
    });
  });

  describe('submitting', () => {
    describe('there are invalid fields', () => {
      it('will not submit');
    });

    describe('there are no invalid fields', () => {

      it('submits a batch of entities to a list endpoint');

      describe('all submissions worked', () => {
        it('redirects to list members tab');
      });

      describe('some submissions failed', () => {
        it('deletes successful submissions from the store');
        it('marks failed submissions with error messages');
        it('renders table with only failed submissions');
      });
    });
  });
});
