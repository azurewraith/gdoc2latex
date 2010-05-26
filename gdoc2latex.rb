#!/usr/bin/ruby

require 'rubygems'
require 'gdata'
require 'gdoc.rb'
require 'base64'
require 'pp'

  DOCLIST_SCOPE = 'http://docs.google.com/feeds/'
  DOCLIST_DOWNLOD_SCOPE = 'http://docs.googleusercontent.com/'
  CONTACTS_SCOPE = 'http://www.google.com/m8/feeds/'
  SPREADSHEETS_SCOPE = 'http://spreadsheets.google.com/feeds/'
  DOCLIST_FEED = DOCLIST_SCOPE + 'default/private/full'
  DOCUMENT_DOC_TYPE = 'document'
  FOLDER_DOC_TYPE = 'folder'
  PRESO_DOC_TYPE = 'presentation'
  PDF_DOC_TYPE = 'pdf'
  SPREADSHEET_DOC_TYPE = 'spreadsheet'
  MINE_LABEL = 'mine'
  STARRED_LABEL = 'starred'
  TRASHED_LABEL = 'trashed'
  MAX_CONTACTS_RESULTS = 500

def create_doc(entry)
    resource_id = entry.elements['gd:resourceId'].text.split(':')
    doc = GDoc::Document.new(entry.elements['title'].text,
                             :type => resource_id[0],
                             :xml => entry.to_s)

    doc.doc_id = resource_id[1]
    doc.last_updated = DateTime.parse(entry.elements['updated'].text)
    if !entry.elements['gd:lastViewed'].nil?
        doc.last_viewed = DateTime.parse(entry.elements['gd:lastViewed'].text)
    end
    if !entry.elements['gd:lastModifiedBy/email'].nil?
        doc.last_modified_by = entry.elements['gd:lastModifiedBy/email'].text
    end
    doc.writers_can_invite = entry.elements['docs:writersCanInvite'].attributes['value']
    doc.author = entry.elements['author/email'].text

    entry.elements.each('link') do |link|
        doc.links[link.attributes['rel']] = link.attributes['href']
    end
    doc.links['acl_feedlink'] = entry.elements['gd:feedLink'].attributes['href']
    doc.links['content_src'] = entry.elements['content'].attributes['src']

    case doc.type
        when DOCUMENT_DOC_TYPE, PRESO_DOC_TYPE
            doc.links['export'] = DOCLIST_SCOPE +
                                  "download/documents/Export?docID=#{doc.doc_id}"
        when SPREADSHEET_DOC_TYPE
            doc.links['export'] = SPREADSHEETS_SCOPE +
                                  "download/spreadsheets/Export?key=#{doc.doc_id}"
        when PDF_DOC_TYPE
            doc.links['export'] = doc.links['content_src']
    end
end

#some hacks to get the perl libs included in html2latex to be imported
path_to_html2latex = '/Users/bcochran/dev/gdocs/html2latex-1.1/'
output = `echo $PERL5LIB`
if output.scan(/#{path_to_html2latex}/).length == 0
    system("export PERL5LIB=$PERL5LIB:#{path_to_html2latex}")
end

filename_base = "gdoc"
client = GData::Client::DocList.new
client.clientlogin('your_email@gmail.com', 'secret')

feed = client.get('http://docs.google.com/feeds/documents/private/full').to_xml

doc_id = nil
feed.elements.each('entry') do |entry|
  title = entry.elements['title'].text
  #set query title to the title of your document
  if title == 'Query Title'
    @document = create_doc(entry)
    pp @document
    puts 'title: ' + title
    type = entry.elements['category'].attribute('label').value
    puts 'type: ' + type
    updated = entry.elements['updated'].text
    puts 'updated: ' + updated
    id = entry.elements['id'].text
    puts 'id: ' + id
    doc_id = entry.elements['id'].text[/full\/(.*%3[aA].*)$/, 1]
    puts 'doc_id: ' + doc_id
    export_url = @document
    puts 'export_url: ' + @document

    resp = client.get(export_url)

    html_string = resp.body.scan(/<body.*<\/body>/m)[0]
    html_string = html_string.sub(/<body.*-->(\r\n)*/m, "<html><body>")
    html_string = html_string.sub(/(<br>\s*)*<\/body>/m, "</body></html>")
    images = html_string.scan(/([\d\w_]*\.png)/m)
    images += html_string.scan(/([\d\w_]*\.jpg)/m)

    html_string = html_string.sub(/^\s*$/m, "")
    file = File.new("gdoc.html", "w")
        file.puts html_string
    file.close

    images.each do |image|
        image_base = image.to_s.sub(/\.(png|jpg)/,'')
        system "wget http://docs.google.com/File?id=#{image_base} -O #{image}"
    end

    system 'perl html2latex-1.1/html2latex gdoc.html'

    texfilename = filename_base + ".tex"

    texfile = File.new(texfilename,'r').read.gsub(/^\s*\\\\\s*$/,'')
    #make further modifications to texfile
    texfile = texfile.gsub(/\\includegraphics\[scale=1\]/, "\\includegraphics[scale=0.6]")
    File.open(texfilename,'w') {|fw| fw.write(texfile)}

    system 'pdflatex gdoc.tex'
    system 'pdflatex gdoc.tex'
    
  end
end




