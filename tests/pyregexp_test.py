import re
from pprint import pprint

cadena = """
        <h2>Template 0.1 test</h2>

        __block(bloque1)__ misma lineaque bloque
            This is a template tests for version 0.1 of Scramjet's templates. The 
            features tested are:
            <ul>
                <li> inserts (on header and footer) </li>
                <li> variable substitucion</li>
                <li> escaping: </li>
            </ul>
        __endblock__

        Texto libre blabla
        <ul>
           <li>Lorem ipsum dolor sit amet, consectetuer adipiscing elit.</li>
           <li>Aliquam tincidunt mauris eu risus.</li>
           <li>Vestibulum auctor dapibus neque.</li>
        </ul>

        __block(bloque2)__

            <p><strong>Pellentesque habitant morbi tristique</strong> senectus et netus et malesuada fames ac turpis egestas. Vestibulum tortor quam, feugiat vitae, ultricies eget, tempor sit amet, ante. Donec eu libero sit amet quam egestas semper. <em>Aenean ultricies mi vitae est.</em> Mauris placerat eleifend leo. Quisque sit amet est et sapien ullamcorper pharetra. Vestibulum erat wisi, condimentum sed, <code>commodo vitae</code>, ornare sit amet, wisi. Aenean fermentum, elit eget tincidunt condimentum, eros ipsum rutrum orci, sagittis tempus lacus enim ac dui. <a href="#">Donec non enim</a> in turpis pulvinar facilisis. Ut felis.</p>

            <h2>Header Level 2</h2>
                       
            <ol>
               <li>Lorem ipsum dolor sit amet, consectetuer adipiscing elit.</li>
               <li>Aliquam tincidunt mauris eu risus.</li>
            </ol>

        __endblock__
        END

        Mas texto libre
        <ol>
           <li>Lorem ipsum dolor sit amet, consectetuer adipiscing elit.</li>
           <li>Aliquam tincidunt mauris eu risus.</li>
           <li>Vestibulum auctor dapibus neque.</li>
        </ol>
"""

tag_re = re.compile(r"(__.*?__)")
pprint(tag_re.split(cadena))
