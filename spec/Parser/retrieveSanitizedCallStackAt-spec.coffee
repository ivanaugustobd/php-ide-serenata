Parser = require '../../lib/Parser'

describe "retrieveSanitizedCallStackAt", ->
    editor = null
    grammar = null
    parser = new Parser(null)

    beforeEach ->
        waitsForPromise ->
            atom.workspace.open().then (result) ->
                editor = result

        waitsForPromise ->
            atom.packages.activatePackage('language-php')

        runs ->
            grammar = atom.grammars.selectGrammar('.source.php')

        waitsFor ->
            grammar and editor

        runs ->
            editor.setGrammar(grammar)

    it "correctly stops at keywords such as parent and self.", ->
        source = "self::foo"
        editor.setText(source)
        expect(parser.retrieveSanitizedCallStackAt(editor, {row: 0, column: source.length})).toEqual(['self', 'foo'])

        source = "parent::foo->test"
        editor.setText(source)
        expect(parser.retrieveSanitizedCallStackAt(editor, {row: 0, column: source.length})).toEqual(['parent', 'foo', 'test'])

    it "correctly stops at static class names.", ->
        source =
            """
            <?php

            if (true) {
                // More code here.
            }

            Bar::testProperty
            """

        editor.setText(source)
        # editor.setGrammar(atom.grammars.selectGrammar('.source.php'))

        expectedResult = [
            'Foo',
            'someProperty'
        ]

        # NOTE: Suggestions welcome: the grammar seems to need time to parse the file, but it's not a promise so we
        # can't wait for it to finish parsing. This is an ugly hack that works around that problem.
        setTimeout(() ->
            expect(parser.retrieveSanitizedCallStackAt(editor, {row: 6, column: 17})).toEqual(expectedResult)
        , 50)

    it "correctly stops at control keywords.", ->
        source =
            """
            <?php

            if (true) {
                // More code here.
            }

            return Foo::someProperty
            """


        editor.setText(source)

        expectedResult = [
            'Foo',
            'someProperty'
        ]

        expect(parser.retrieveSanitizedCallStackAt(editor, {row: 6, column: 24})).toEqual(expectedResult)


    it "correctly stops at built-in constructs.", ->
        source =
            """
            <?php

            if (true) {
                // More code here.
            }

            echo Foo::someProperty
            """


        editor.setText(source)

        expectedResult = [
            'Foo',
            'someProperty'
        ]

        expect(parser.retrieveSanitizedCallStackAt(editor, {row: 6, column: 22})).toEqual(expectedResult)

    it "correctly sanitizes complex call stacks, interleaved with things such as comments, closures and chaining.", ->
        source =
            """
            $this
                ->testChaining(5, ['Somewhat more complex parameters', /* inline comment */ null])
                //------------
                /*
                    another comment$this;[]{}**** /*
                */
                ->testChaining(2, [
                //------------
                    'value1',
                    'value2'
                ])

                ->testChaining(
                //------------
                    3,
                    [],
                    function (FooClass $foo) {
                        //    --------
                        return $foo;
                    }
                )

                ->testChaining(
                //------------
                    nestedCall() - (2 * 5),
                    nestedCall() - 3
                )

                ->testChai
            """

        editor.setText(source)

        expectedResult = [
            '$this',
            'testChaining()',
            'testChaining()',
            'testChaining()',
            'testChaining()',
            'testChai'
        ]

        expect(parser.retrieveSanitizedCallStackAt(editor, [32, 10])).toEqual(expectedResult)
