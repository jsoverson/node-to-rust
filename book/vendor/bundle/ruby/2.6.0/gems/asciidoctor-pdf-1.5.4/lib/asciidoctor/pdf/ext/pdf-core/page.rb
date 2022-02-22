# frozen_string_literal: true

class PDF::Core::Page
  InitialPageContent = %(q\n)

  # Restore the new_content_stream method from PDF::Core::Page
  #
  # The prawn-templates gem relies on the new_content_stream method on
  # PDF::Core::Page, which was removed in pdf-core 0.3.1. prawn-templates is
  # used for importing a single-page PDF into the current document.
  #
  # see https://github.com/prawnpdf/pdf-core/commit/67f9a08a03bcfcc5a24cf76b135c218d3d3ab05d
  def new_content_stream
    return if in_stamp_stream?
    dictionary.data[:Contents] = [content] unless Array === dictionary.data[:Contents]
    @content = document.ref({})
    dictionary.data[:Contents] << document.state.store[@content]
    document.open_graphics_state
  end unless method_defined? :new_content_stream

  # NOTE alias method to avoid warning if another gem replaces this method
  alias __new_content_stream new_content_stream

  # Restore the imported_page? method from PDF::Core::Page
  #
  # see https://github.com/prawnpdf/pdf-core/commit/0e326a838e142061be8e062168190fae6b3b1dcf
  def imported_page?
    @imported_page
  end unless method_defined? :imported_page?

  # Record the page's current state as the tare content stream (i.e., empty, meaning no content has been written).
  def tare_content_stream
    @tare_content_stream = content.stream.filtered_stream
  end

  # Returns whether the current page is empty based on tare content stream (i.e., no content has been written).
  # Returns false if a page has not yet been created.
  def empty?
    content.stream.filtered_stream == (@tare_content_stream ||= InitialPageContent) && document.page_number > 0
  end

  # Reset the content of the page.
  # Note that this method may leave behind an orphaned background image.
  def reset_content
    unless content.stream.filtered_stream == InitialPageContent
      xobjects.clear
      ext_gstates.clear
      new_content = document.state.store[document.ref({})]
      new_content << 'q' << ?\n
      content.replace new_content
      @tare_content_stream = InitialPageContent
    end
  end
end
