# == Source::Parser::Ical
#
# Reads iCalendar events.
#
# Example:
#   events = Source::Parser::Ical.to_events('http://appendix.23ae.com/calendars/AlternateHolidays.ics')
#
# Sample sources:
#   webcal://appendix.23ae.com/calendars/AlternateHolidays.ics
#   http://appendix.23ae.com/calendars/AlternateHolidays.ics
module Calagator

class Source::Parser::Ical < Source::Parser
  self.label = :iCalendar

  VENUE_CONTENT_RE = /^BEGIN:VVENUE$.*?^END:VVENUE$/m

  # Override Base::read_url to handle "webcal" scheme addresses.
  def self.read_url(url)
    super(url.gsub(/^webcal:/, 'http:'))
  end

  def to_events
    return false unless calendars = content_calendars

    events = calendars.flat_map do |calendar|
      calendar.events.map do |component|
        next if old?(component)
        component_to_event(component, calendar)
      end
    end

    events.compact.uniq do |event|
      [event.attributes, event.venue.try(:attributes)]
    end
  end

  private

  def old?(component)
    cutoff = Time.now.yesterday
    (component.dtend || component.dtstart).to_time < cutoff
  end

  def content_calendars
    content = self.class.read_url(url).gsub(/\r\n/, "\n")
    content = munge_gmt_dates(content)
    RiCal.parse_string(content)
  rescue Exception => exception
    return false if exception.message =~ /Invalid icalendar file/ # Invalid data, give up.
    raise # Unknown error, reraise
  end

  def component_to_event(component, calendar)
    event = Event.new({
      source:      source,
      title:       component.summary,
      description: component.description,
      url:         component.url,
      start_time:  normalized_start_time(component),
      end_time:    normalized_end_time(component),
      venue:       to_venue(content_venue(component, calendar), component.location),
    })
    event_or_duplicate(event)
  end

  def content_venue(component, calendar)
    content_venues = calendar.to_s.scan(VENUE_CONTENT_RE)

    # finding the event venue id - VVENUE=V0-001-001423875-1@eventful.com
    venue_uid = component.location_property.params["VVENUE"]
    # finding in the content_venues array an item matching the uid
    venue_uid ? content_venues.find{|content_venue| content_venue.match(/^UID:#{venue_uid}$/m)} : nil
  rescue => exception
    Rails.logger.info("Source::Parser::Ical.to_events : Failed to parse content_venue for event -- #{exception}")
    nil
  end

  # Helper to set the start and end dates correctly depending on whether it's a floating or fixed timezone
  def normalized_start_time(component)
    if component.dtstart_property.tzid
      component.dtstart
    else
      Time.zone.parse(component.dtstart_property.value)
    end
  end

  # Helper to set the start and end dates correctly depending on whether it's a floating or fixed timezone
  def normalized_end_time(component)
    if component.dtstart_property.tzid
      component.dtend
    elsif component.dtend_property
      Time.zone.parse(component.dtend_property.value)
    elsif component.duration
      component.duration_property.add_to_date_time_value(normalized_start_time(component))
    else
      normalized_start_time(component)
    end
  end

  def munge_gmt_dates(content)
    content.gsub(/;TZID=GMT:(.*)/, ':\1Z')
  end

  # Return an Venue extracted from an iCalendar input.
  #
  # Arguments:
  # * value - String with iCalendar data to parse which contains a VVENUE item.
  # * fallback - String to use as the title for the location if the +value+ doesn't contain a VVENUE.
  def to_venue(value, fallback=nil)
    venue = Venue.new

    # VVENUE entries are considered just Vcards,
    # treating them as such.
    if vcard_hash = vcard_hash_from_value(value)
      venue.attributes = {
        title:          vcard_hash['NAME'],
        street_address: vcard_hash['ADDRESS'],
        locality:       vcard_hash['CITY'],
        region:         vcard_hash['REGION'],
        postal_code:    vcard_hash['POSTALCODE'],
        country:        vcard_hash['COUNTRY'],
      }
      venue.latitude, venue.longitude = vcard_hash['GEO'].split(/;/).map(&:to_f)

    elsif fallback.present?
      venue.title = fallback
    else
      return nil
    end

    venue.geocode!
    venue_or_duplicate(venue)
  end

  def vcard_hash_from_value(value)
    value ||= ""
    return unless data = value.scan(VENUE_CONTENT_RE).first

    # Only use first vcard of a VVENUE
    vcard = RiCal.parse_string(data).first

    # Extract all properties, including non-standard ones, into an array of "KEY;meta-qualifier:value" strings
    vcard_lines = vcard.export_properties_to(StringIO.new(''))

    # Turn a String-like object into an Enumerable.
    vcard_lines = vcard_lines.respond_to?(:lines) ? vcard_lines.lines : vcard_lines

    hash_from_vcard_lines(vcard_lines)
  end

  # Return hash parsed from VCARD lines.
  #
  # Arguments:
  # * vcard_lines - Array of "KEY;meta-qualifier:value" strings.
  def hash_from_vcard_lines(vcard_lines)
    vcard_lines.reduce({}) do |vcard_hash, vcard_line|
      if matcher = vcard_line.match(/^([^;]+?)(;[^:]*?)?:(.*)$/)
        _, key, qualifier, value = *matcher

        if qualifier
          # Add entry for a key and its meta-qualifier
          vcard_hash["#{key}#{qualifier}"] = value

          # Add fallback entry for a key from the matching meta-qualifier, e.g. create key "foo" from contents of key with meta-qualifier "foo;bar".
          vcard_hash[key] ||= value
        else
          # Add entry for a key without a meta-qualifier.
          vcard_hash[key] = value
        end
      end
      vcard_hash
    end
  end
end

end
