from test_support import *

exec_cmd('ada2wsdl',
         ['-v', '-f', '-I.', '-Pwsdl_d', 'wsdl_d.ads',
          '-o', 'wsdl_d.wsdl'],
         output_file='ada2wsdl.res')

tail('ada2wsdl.res', 'test.res', 3)
diff()
