from django.core.management import setup_environ
from django.template.loader import render_to_string
from django.template import Context, Template
import settings

setup_environ(settings)

num = 10000

#for i in xrange(num):
    #c = Context({"testvarstring": "polompos & <>", "testvarfloat": 3.14, "assocarray1": {"polompos": "pok"}, "listassoc": [{"polompos": "pok"}, {"cogorcios": 3}]})
    #s = render_to_string('niece_template.html', c)

#print s


table = [dict(a=1,b=2,c=3,d=4,e=5,f=6,g=7,h=8,i=9,j=10) for x in range(1000)]

c = Context({'table': table})
s = render_to_string('bigtable.html', c)

