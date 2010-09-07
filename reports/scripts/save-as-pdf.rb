include_class 'java.io.BufferedReader'
include_class 'java.io.FileNotFoundException'
include_class 'java.io.FileOutputStream'
include_class 'java.io.FileReader'
include_class 'java.io.IOException'
include_class 'java.lang.System'

include_class 'javax.swing.JFileChooser'

include_class 'com.itextpdf.text.Document'
include_class 'com.itextpdf.text.DocumentException'
include_class 'com.itextpdf.text.html.simpleparser.HTMLWorker'
include_class 'com.itextpdf.text.pdf.PdfWriter'

include_class 'org.concord.otrunk.OTMLToXHTMLConverter'

def clicked
  ConverterThread.new().start()  
end

class ConverterThread < java.lang.Thread

  def run
    
    unless $printObject
     $printObject = $viewContainer.parentContainer.currentObject
    end
  
    unless $printViewEntry
      $printViewEntry = $viewContainer.parentContainer.currentViewEntry
    end
    
    fc = JFileChooser.new
    defaultFile = java.io.File.new(
      java.io.File.new(System.getProperty('user.home')), 'report.pdf')
    fc.setSelectedFile(defaultFile)
    retval = fc.showSaveDialog(nil)
    return unless retval == JFileChooser::APPROVE_OPTION
    
    pdf_file = fc.getSelectedFile

    htmlConverter = OTMLToXHTMLConverter.new(
      $viewContext.createChildViewFactory, $printObject,
      $printViewEntry, "print")
    html_file = java.io.File.createTempFile("ot_print",".html")
    htmlConverter.setXHTMLParams(html_file, 800, 600)
    htmlConverter.run
    
    html_path1 = html_file.getAbsolutePath
    html_path2 = html_path1 + '.2'
    html_dir = File.dirname(html_path1)
      
    open(html_path1, 'r') do |html_file1|
      open(html_path2, 'w') do |html_file2|
        html_file2.write(html_file1.read.gsub(/src=["']([^'"]*?)["']/m) {
          m1 = $1
          path = (m1 =~ /^\//) ? m1 : "#{html_dir}/#{m1}"
          "src=\"#{path}\""
        })
      end
    end
    
    document = Document.new
    PdfWriter.getInstance(document, FileOutputStream.new(pdf_file))
    document.open
    worker = HTMLWorker.new(document)
    reader = BufferedReader.new(FileReader.new(java.io.File.new(html_path2)))
    worker.parse(reader)
    document.close
  end
end
