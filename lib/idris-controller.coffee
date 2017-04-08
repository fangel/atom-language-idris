{ MessagePanelView, PlainMessageView, LineMessageView } =
  require 'atom-message-panel'
InformationView = require './views/information-view'
HolesView = require './views/holes-view'
Logger = require './Logger'
IdrisModel = require './idris-model'
Ipkg = require './utils/ipkg'
Symbol = require './utils/symbol'
editorHelper = require './utils/editor'

class IdrisController
  errorMarkers: []

  isIdrisFile: (uri) ->
    uri?.match? /\.idr$/

  createMarker: (editor, range, type) ->
    marker = editor.markBufferRange(range, invalidate: 'never')
    editor.decorateMarker marker,
      type: type
      class: 'highlight-idris-error'
    marker

  destroyMarkers: () ->
    for marker in @errorMarkers
      marker.destroy()

  destroy: ->
    if @model
      Logger.logText 'Idris: Shutting down!'
      @model.stop()
    @statusbar.destroy()

  # get the word or operator under the cursor
  getWordUnderCursor: (editor) ->
    options =
      wordRegex: /(^[	 ]*$|[^\s\/\\\(\)":,\.;<>~!@#\$%\^&\*\|\+=\[\]\{\}`\?\-…]+)|(\?[-!#\$%&\*\+\.\/<=>@\\\^\|~:]+|[-!#\$%&\*\+\.\/<=>@\\\^\|~:][-!#\$%&\*\+\.\/<=>@\\\^\|~:\?]*)+/g
    cursorPosition = editor.getLastCursor().getCurrentWordBufferRange options
    editor.getTextInBufferRange cursorPosition

  initialize: (compilerOptions) ->
    @destroyMarkers()
    if !@model
      @model = new IdrisModel
      @messages = new MessagePanelView
        title: 'Idris Messages'
      @messages.attach()
      @messages.hide()
    @model.setCompilerOptions compilerOptions

  getEditor: () ->
    atom.workspace.getActiveTextEditor()

  stopCompiler: =>
    @model?.stop()

  runCommand:
    (command) =>
      (args) =>
        compilerOptions = Ipkg.compilerOptions atom.project
        compilerOptions.subscribe (options) =>
          console.log "Compiler Options:", options
          @initialize options
          command args

  # see https://github.com/atom/autocomplete-plus/wiki/Provider-API
  provideReplCompletions: =>
    selector: '.source.idris'

    inclusionPriority: 1
    excludeLowerPriority: false

    # Get suggestions from the Idris REPL. You can always ask for suggestions <Ctrl+Space>
    # or type at least 3 characters to get suggestions based on your autocomplete-plus
    # settings.
    getSuggestions: ({ editor, bufferPosition, scopeDescriptor, prefix, activatedManually }) =>
      trimmedPrefix = prefix.trim()
      if trimmedPrefix.length > 2 or activatedManually
        Ipkg.compilerOptions atom.project
          .flatMap (options) =>
            @initialize options
            @model
              .replCompletions trimmedPrefix
          .toPromise()
          .then ({ responseType, msg }) ->
            for sug in msg[0][0]
              type: "function"
              text: sug
      else
        null

  saveFile: (editor) ->
    if editor.getURI()
      editor.save()
    else
      atom.workspace.saveActivePaneItemAs()

  typecheckFile: (event) =>
    editor = @getEditor()
    @saveFile editor
    uri = editor.getURI()
    @messages.setTitle 'Idris: Typechecking...'
    @messages.clear()

    successHandler = ({ responseType, msg }) =>
      @messages.attach()
      @messages.show()
      @messages.clear()
      @messages.setTitle 'Idris: File loaded successfully'

    @model
      .load uri
      .filter ({ responseType }) -> responseType == 'return'
      .subscribe successHandler, @displayErrors

  getDocsForWord: ({ target }) =>
    editor = @getEditor()
    @saveFile editor
    uri = editor.getURI()
    word = Symbol.serializeWord @getWordUnderCursor(editor)

    successHandler = ({ responseType, msg }) =>
      [type, highlightingInfo] = msg
      @messages.attach()
      @messages.show()
      @messages.clear()
      @messages.setTitle 'Idris: Docs for <tt>' + word + '</tt>', true
      informationView = new InformationView
      informationView.initialize
        obligation: type
        highlightingInfo: highlightingInfo
      @messages.add informationView

    @model
      .load uri
      .filter ({ responseType }) -> responseType == 'return'
      .flatMap => @model.docsFor word
      .catch (e) => @model.docsFor word
      .subscribe successHandler, @displayErrors

  getTypeForWord: ({ target }) =>
    editor = @getEditor()
    @saveFile editor
    uri = editor.getURI()
    word = Symbol.serializeWord @getWordUnderCursor(editor)

    successHandler = ({ responseType, msg }) =>
      [type, highlightingInfo] = msg
      @messages.attach()
      @messages.show()
      @messages.clear()
      @messages.setTitle 'Idris: Type of <tt>' + word + '</tt>', true
      informationView = new InformationView
      informationView.initialize
        obligation: type
        highlightingInfo: highlightingInfo
      @messages.add informationView

    @model
      .load uri
      .filter ({ responseType }) -> responseType == 'return'
      .flatMap => @model.getType word
      .subscribe successHandler, @displayErrors

  doCaseSplit: ({ target }) =>
    editor = @getEditor()
    @saveFile editor
    uri = editor.getURI()
    cursor = editor.getLastCursor()
    line = cursor.getBufferRow()
    word = @getWordUnderCursor editor

    successHandler = ({ responseType, msg }) ->
      [split] = msg
      lineRange = cursor.getCurrentLineBufferRange(includeNewline: true)
      editor.setTextInBufferRange lineRange, split

    @model
      .load uri
      .filter ({ responseType }) -> responseType == 'return'
      .flatMap => @model.caseSplit line + 1, word
      .subscribe successHandler, @displayErrors

  doAddClause: ({ target }) =>
    editor = @getEditor()
    @saveFile editor
    uri = editor.getURI()
    line = editor.getLastCursor().getBufferRow()
    word = @getWordUnderCursor editor

    successHandler = ({ responseType, msg }) ->
      [clause] = msg
      editor.transact ->
        editorHelper.moveToNextEmptyLine editor

        # Insert the new clause
        editor.insertText clause

        # And move the cursor to the beginning of
        # the new line and add an empty line below it
        editor.insertNewlineBelow()
        editor.moveUp()
        editor.moveToBeginningOfLine()

    @model
      .load uri
      .filter ({ responseType }) -> responseType == 'return'
      .flatMap => @model.addClause line + 1, word
      .subscribe successHandler, @displayErrors

  doMakeWith: ({ target }) =>
    editor = @getEditor()
    @saveFile editor
    uri = editor.getURI()
    line = editor.getLastCursor().getBufferRow()
    word = @getWordUnderCursor editor

    successHandler = ({ responseType, msg }) ->
      [clause] = msg
      editor.transact ->
        # Delete old line, insert the new with block
        editor.deleteLine()
        editor.insertText clause
        # And move the cursor to the beginning of
        # the new line
        editor.moveToBeginningOfLine()
        editor.moveUp()


    @model
      .load uri
      .filter ({ responseType }) -> responseType == 'return'
      .flatMap => @model.makeWith line + 1, word
      .subscribe successHandler, @displayErrors

  doMakeLemma: ({ target }) =>
    editor = @getEditor()
    @saveFile editor
    uri = editor.getURI()
    line = editor.getLastCursor().getBufferRow()
    word = @getWordUnderCursor editor

    successHandler = ({ responseType, msg }) ->
      [lemty, param1, param2] = msg
      editor.transact ->
        if lemty == ':metavariable-lemma'
          # Move the cursor to the beginning of the word
          editor.moveToBeginningOfWord()
          # Because the ? in the Holes isn't part of
          # the word, we move left once, and then select two
          # words
          editor.moveLeft()
          editor.selectToEndOfWord()
          editor.selectToEndOfWord()
          # And then replace the replacement with the lemma call..
          editor.insertText param1[1]

          # Now move to the previous blank line and insert the type
          # of the lemma
          editor.moveToBeginningOfLine()
          line = editor.getLastCursor().getBufferRow()

          # I tried to make this a function but failed to find out how
          # to call it and gave up...
          while(line > 0)
            editor.moveToBeginningOfLine()
            editor.selectToEndOfLine()
            contents = editor.getSelectedText()
            if contents == ''
              break
            editor.moveUp()
            line--

          editor.insertNewlineBelow()
          editor.insertText param2[1]
          editor.insertNewlineBelow()

    @model
      .load uri
      .filter ({ responseType }) -> responseType == 'return'
      .flatMap => @model.makeLemma line + 1, word
      .subscribe successHandler, @displayErrors

  doMakeCase: ({ target }) =>
    editor = @getEditor()
    @saveFile editor
    uri = editor.getURI()
    line = editor.getLastCursor().getBufferRow()
    word = @getWordUnderCursor editor

    successHandler = ({ responseType, msg }) ->
      [clause] = msg
      editor.transact ->
        # Delete old line, insert the new case block
        editor.deleteLine()
        editor.insertText clause
        # And move the cursor to the beginning of
        # the new line
        editor.moveToBeginningOfLine()
        editor.moveUp()

    @model
      .load uri
      .filter ({ responseType }) -> responseType == 'return'
      .flatMap => @model.makeCase line + 1, word
      .subscribe successHandler, @displayErrors

  showHoles: ({ target }) =>
    editor = @getEditor()
    @saveFile editor
    uri = editor.getURI()

    successHandler = ({ responseType, msg }) =>
      [holes] = msg
      @messages.attach()
      @messages.show()
      @messages.clear()
      @messages.setTitle 'Idris: Holes'
      holesView = new HolesView
      holesView.initialize holes
      @messages.add holesView

    @model
      .load uri
      .filter ({ responseType }) -> responseType == 'return'
      .flatMap => @model.holes 80
      .subscribe successHandler, @displayErrors

  doProofSearch: ({ target }) =>
    editor = @getEditor()
    @saveFile editor
    uri = editor.getURI()
    line = editor.getLastCursor().getBufferRow()
    word = @getWordUnderCursor editor

    successHandler = ({ responseType, msg }) ->
      [res] = msg
      editor.transact ->
        # Move the cursor to the beginning of the word
        editor.moveToBeginningOfWord()
        # Because the ? in the Holes isn't part of
        # the word, we move left once, and then select two
        # words
        editor.moveLeft()
        editor.selectToEndOfWord()
        editor.selectToEndOfWord()
        # And then replace the replacement with the guess..
        editor.insertText res

    @model
      .load uri
      .filter ({ responseType }) -> responseType == 'return'
      .flatMap => @model.proofSearch line + 1, word
      .subscribe successHandler, @displayErrors

  printDefinition: ({ target }) =>
    editor = @getEditor()
    @saveFile editor
    uri = editor.getURI()
    word = Symbol.serializeWord @getWordUnderCursor(editor)

    successHandler = ({ responseType, msg }) =>
      [type, highlightingInfo] = msg
      @messages.attach()
      @messages.show()
      @messages.clear()
      @messages.setTitle 'Idris: Definition of <tt>' + word + '</tt>', true
      informationView = new InformationView
      informationView.initialize
        obligation: type
        highlightingInfo: highlightingInfo
      @messages.add informationView

    @model
      .load uri
      .filter ({ responseType }) -> responseType == 'return'
      .flatMap => @model.printDefinition word
      .catch (e) => @model.printDefinition word
      .subscribe successHandler, @displayErrors

  openREPL: ({ target }) =>
    uri = @getEditor().getURI()

    successHandler = ({ responseType, msg }) ->
      options =
        split: 'right'
        searchAllPanes: true

      atom.workspace.open "idris://repl", options

    @model
      .load uri
      .filter ({ responseType }) -> responseType == 'return'
      .subscribe successHandler, @displayErrors

  apropos: ({ target }) =>
    uri = @getEditor().getURI()

    successHandler = ({ responseType, msg }) ->
      options =
        split: 'right'
        searchAllPanes: true

      atom.workspace.open "idris://apropos", options

    @model
      .load uri
      .filter ({ responseType }) -> responseType == 'return'
      .subscribe successHandler, @displayErrors

  displayErrors: (err) =>
    @messages.attach()
    @messages.show()
    @messages.clear()
    @messages.setTitle '<i class="icon-bug"></i> Idris Errors', true

    @messages.add new PlainMessageView
      message: "Errors (#{err.warnings.length})"
      className: 'idris-error'

    for warning in err.warnings
      line = warning[1][0]
      character = warning[1][1]
      uri = warning[0].replace("./", err.cwd + "/")

      @messages.add new LineMessageView
        line: line
        character: character
        preview: warning[3]
        file: uri

      editor = atom.workspace.getActiveTextEditor()
      if line > 0 && uri == editor.getURI()
        startPoint = warning[1]
        startPoint[0] = startPoint[0] - 1
        endPoint = warning[2]
        endPoint[0] = endPoint[0] - 1
        gutterMarker = @createMarker editor, [startPoint, endPoint], 'line-number'
        lineMarker = @createMarker editor, [[line - 1, character - 1], [line, 0]], 'line'
        @errorMarkers.push gutterMarker
        @errorMarkers.push lineMarker

module.exports = IdrisController
