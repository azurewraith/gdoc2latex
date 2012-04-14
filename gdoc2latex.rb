#!/usr/bin/ruby

require 'rubygems'
require 'date'
require 'gdata'
require 'gdoc.rb'
require 'base64'
require 'pp'
require 'highline/import'
require 'pandoc-ruby'

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

if ARGV.length != 3
  puts "Usage: gdoc2ruby.rb <target_directory> <template> <google_login>"
  exit 0
end 

filename_base = ARGV[0]
template_name = ARGV[1]
google_login = ARGV[2]

system("mkdir #{filename_base}")
system("cp templates/#{template_name}/* #{filename_base}/.")
Dir.chdir "#{filename_base}"

password = ask("\nEnter Google Password: ") { |q| q.echo = false }

client = GData::Client::DocList.new
client.clientlogin(google_login, password)

feed = client.get('https://docs.google.com/feeds/documents/private/full').to_xml

counter = 1
docs = Hash.new
feed.elements.each('entry') do |entry|
  docs[counter] = entry
  counter = counter + 1
  
  if counter > 10
    break
  end
end

puts "10 Most Recent Documents"
puts "------------------------"
docs.each { |id, entry| puts "#{id} : #{entry.elements['title'].text}" }

print "\nChoose a document id: "
picked_id = STDIN.gets.chomp

doc_id = nil
docs.each do |id, entry|
  #puts id
  #puts entry
  title = entry.elements['title'].text
  #set query title to the title of your document
  if picked_id.to_s == id.to_s
    @document = create_doc(entry)
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
    export_url = export_url.sub(/http/, "https")
    export_url = export_url.sub(/docID=/, "id=")
    resp = client.get(export_url)

    html_string = resp.body.scan(/<body.*<\/body>/m)[0]
    html_string = html_string.sub(/<body.*-->(\r\n)*/m, "<html><body>")
    #html_string = html_string.gsub(/&nbsp;/m, "~~")
    html_string = html_string.gsub(/&ldquo;/m, "&quot;")
    html_string = html_string.gsub(/&rdquo;/m, "&quot;")
    html_string = html_string.gsub(/&lsquo;/m, "&#39;")
    html_string = html_string.gsub(/&rsquo;/m, "&#39;")
    html_string = html_string.sub(/(<br>\s*)*<\/body>/m, "</body></html>")
   
    image_blocks = html_string.scan(/src="(ftp|http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?"/)
    counter = 0;
    image_blocks.each do |image_b|
      url = image_b[0] + "://" + image_b[2]
      url_mod = url.gsub(/\%7B/m, "{")
      url_mod = url_mod.gsub(/\%7D/m, "}")
      url_mod = url_mod.gsub(/&amp;/m, "&")
      extension = ".png"
      filename = counter.to_s + extension
      counter += 1
      system "wget --no-check-certificate \"#{url_mod}\" -O #{filename}"
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   
      #html_string = html_string.gsub(/#{url.chomp}/m, "#{filename}")
      html_string = html_string.sub(url, filename)
    end 
    
    html_string = html_string.sub(/^\s*$/m, "")
    file = File.new("#{filename_base}.html", "w")
    file.write html_string
    file.close

    PandocRuby.allow_file_paths = true
    latex = PandocRuby.html("./#{filename_base}.html").to_latex
    latex_file = File.new("#{filename_base}.tex", "w")
    latex_file.write(latex)
    latex_file.close

    template_filename = "template.tex"
    texfilename = filename_base + ".tex"

    template = File.new(template_filename,'r').read
    texfile = File.new(texfilename,'r').read
    
    #make further modifications to texfile

    texfile = texfile.gsub(/\\includegraphics/, "\\includegraphics[scale=0.6]")
    #texfile = texfile.gsub(/ /, " ")
    #texfile = texfile.gsub(/``/, "\"")
    #texfile = texfile.gsub(/''/, "\"")
    texfile = texfile.gsub(/\\textbackslash\{\}/, '\\')
    texfile = texfile.gsub(/\\\{/, '{')
    texfile = texfile.gsub(/\\\}/, '}')
    texfile = texfile.gsub(/\\textasciitilde\{\}/m, "")

    # remove comments
    texfile = texfile.gsub(/\\href.*\}/, "")
    texfile = texfile.gsub(/\\textsuperscript\{/, "}")

    # if utdiss2 template, promote sections to chapters
    if (template_name == "utdiss2")
      texfile = texfile.gsub(/\\section/, "\\chapter")
      texfile = texfile.gsub(/\\(.*)subsection/) do
        "\\#{$1}section"
      end
    end
    
    #unescape inline formulas
    #texfile = texfile.gsub(/\\\$/, '$')
    #texfile = texfile.gsub(/\\\^/, '^')
    #texfile = texfile.gsub(/\\\_/, '_')
    
    #tempfix for protocol messages
    #texfile = texfile.gsub(/([A-Z])_([A-Z])/, '\1\_\2')
    #texfile = texfile.gsub(/\\begin\{lstlisting\}.*\\end\{lstlisting\}/, 'insert code!')

    #figure reformatting
    #texfile = texfile.gsub(/Figure \{(.*)\}: (.*)/) do
    #  "\\begin{figure}[h]\n\\centering\n\\includegraphics[scale=0.6]{./0.png}\n\\caption{#{$2}}\n\\label{#{$1}}\n\\end{figure}"
    #end

    #substitute file content for the <yield> in the template
    
    template = template.gsub(/<yield>/, texfile)
    
    File.open(texfilename,'w') {|fw| fw.write(template)}
    
    system "pdflatex #{filename_base}.tex"
    system "pdflatex #{filename_base}.tex"
    
  end
end

