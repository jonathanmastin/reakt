{ok: expect, equal} = require('assert')
spy   = require('bondjs')

child = require('child_process')
watch = require('watch')
_     = require('underscore')

reakt = require('./index')

describe 'reakt', ->

  createSubject = (args = {}) ->
    subject = reakt("/foo/bar", 'ls ..', args)
    # Silence is golden
    spy(subject, 'log').return()
    subject

  beforeEach ->
    @subject = createSubject()

  describe '#start', ->
    beforeEach ->
      spy(watch, 'watchTree').return()
      spy(_, 'after').return()
      spy(@subject, 'processRestarter').return()
      spy(@subject, 'startProcess').return()
      @expectedStartFn = @subject.startProcess
      @subject.start()

    context 'when in long running mode', ->
      beforeEach ->
        @subject = createSubject(longRunning: true)
        spy(@subject, 'processRestarter').return()
        spy(@subject, 'startProcess').return()
        @expectedStartFn = @subject.startProcess
        @subject.start()

      it 'starts the process with #startProcess', ->
        expect @expectedStartFn.called

      it 'wraps the #startProcess method with a #processRestarter', ->
        [actualStartFn] = @subject.processRestarter.calledArgs[0]
        equal actualStartFn, @expectedStartFn

    context 'when not in long running mode', ->
      it 'does not start the process', ->
        expect not @expectedStartFn.called

      it 'does not wrap the startProcess method', ->
        expect not @subject.processRestarter.called

    it 'ensures that the #onChange handler is ran after the second invocation', ->
      [times, cb] = _.after.calledArgs[0]

    it 'sets a watcher on the provided path', ->
      [path, cb] = watch.watchTree.calledArgs[0]
      equal path, "/foo/bar"
      equal cb, @subject.onChange


  describe '#onChange', ->
    beforeEach ->
      @fakeData = ['foo']
      spy(@subject, 'parseFiles').return(@fakeData)
      spy(@subject, 'startProcess').return()

    context 'with no files', ->
      it 'returns early', ->
        @subject.parseFiles.return([])
        @subject.onChange(@fakeData)
        expect not @subject.startProcess.called

    context 'with files', ->
      it 'calls #runProcess', ->
        @subject.parseFiles.return(['/foo'])
        @subject.onChange(@fakeData)
        expect @subject.startProcess.called

  describe '#parseFiles', ->
    context 'when called with an object', ->
      it 'converts the objects keys to a string and returns it', ->
        result = @subject.parseFiles({'foo','bar'})
        equal result[0], 'foo'
        equal result[1], 'bar'

    context 'when called with a string', ->
      it 'returns the original string', ->
        result = @subject.parseFiles('foo')
        equal result[0], 'foo'

  describe '#parseFile', ->
    beforeEach ->
      @subject = createSubject(include: "(baz\/qux|lorem\/ipsum)", exclude: "ipsum\/lorem")

    it 'strips the base path', ->
      equal @subject.parseFile('/foo/bar/baz/qux'), '/baz/qux'

    context 'if the file does not match the include pattern', ->
      it 'returns null', ->
        equal @subject.parseFile('/foo/bar/foo/ipsum'), null

    context 'if the file matches the exclude pattern', ->
      it 'returns null', ->
        equal @subject.parseFile('/foo/bar/ipsum/lorem'), null

  describe '#startProcess', ->
    it 'spawns a child process', ->
      spy(child, 'spawn').return()
      @subject.startProcess()

      [cmd, args, opts] = child.spawn.calledArgs[0]
      equal cmd, 'sh'
      equal args[0], '-c'
      equal args[1], 'ls ..'
      equal opts.stdio, 'inherit'

  describe '#processRestarter', ->
    beforeEach ->
      @startFnSpy = spy().return('foo')
      @result = @subject.processRestarter(@startFnSpy)
      @subject.process =
        on: spy()
        kill : spy()
      spy(@subject, 'onProcessExit').return('bar')
      @result()

    context 'with a running process', ->
      it 'registers an exit handler on the process', ->
        [event, cb] =  @subject.process.on.calledArgs[0]
        equal event, 'exit'
        equal cb, 'bar'

      it 'kills the process', ->
        expect @subject.process.kill.called

    context 'without a process', ->
      it 'starts the process', ->
        @subject.process = null
        @result()
        equal @subject.process, 'foo'

  describe '#onProcessExit', ->
    beforeEach ->
      @startFnSpy = spy().return('foo')
      @result = @subject.onProcessExit({}, @startFnSpy)
      @result()

    it 'starts the process', ->
      expect @startFnSpy.called
      equal @subject.process, 'foo'

