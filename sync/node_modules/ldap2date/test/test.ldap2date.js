var assert = require('assert')
var ldap2date = require('../ldap2date')

describe('ldap2date', function () {
  var time
  before(function() {
    time = '20130228192706.607Z'
  })
  describe('getYear', function() {
    it('should parse the year', function() {
      var year = ldap2date.getYear(time)
      assert.strictEqual(year, 2013)
    })
  })

  describe('getMonth', function() {
    it('should parse the month', function() {
      var month = ldap2date.getMonth(time)
      assert.strictEqual(month, 1)
    })
  })

  describe('getDay', function() {
    it('should parse the day', function() {
      var day = ldap2date.getDay(time)
      assert.strictEqual(day, 28)
    })
  })

  describe('getHours', function() {
    it('should parse the hours', function() {
      var hour = ldap2date.getHours(time)
      assert.strictEqual(hour, 19)
    })
  })
  
  describe('getMinutes', function() {
    it('should parse the minutes', function() {
      var minutes = ldap2date.getMinutes(time)
      assert.strictEqual(minutes, 27)
    })

    it('should return 0 if minutes are not present', function() {
      var minutes = ldap2date.getMinutes('2013022819.607Z')
      assert.strictEqual(minutes, 0)
    })
  })

  describe('getSeconds', function() {
    it('should parse the seconds', function() {
      var seconds = ldap2date.getSeconds(time)
      assert.strictEqual(seconds, 6)
    })

    it('should return 0 if seconds are not present', function() {
      var seconds = ldap2date.getSeconds('201302281927.607Z')
      assert.strictEqual(seconds, 0)
    })
  })

  describe('getMilliseconds', function() {
    it('should parse the milliseconds', function() {
      var ms = ldap2date.getMilliseconds(time)
      assert.strictEqual(ms, 607)
    })

    it('should parse ms even if minutes/seconds are missing', function() {
      var ms = ldap2date.getMilliseconds('2013022819.648Z')
      assert.strictEqual(ms, 648)
    })

    it('should work with commas', function() {
      var ms = ldap2date.getMilliseconds('2013022819,648Z')
      assert.strictEqual(ms, 648)
    })

    it('should return 0 if milliseconds are not present', function() {
      var ms = ldap2date.getMilliseconds('20130228192706Z')
      assert.strictEqual(ms, 0)
    })

    it('should handle 2 digit fractions', function() {
      var ms = ldap2date.getMilliseconds('20130228192706.12Z')
      assert.strictEqual(ms, 120)
    })

    it('should handle 1 digit fractions', function() {
      var ms = ldap2date.getMilliseconds('20130228192706.8Z')
      assert.strictEqual(ms, 800)
    })
  })

  describe('getTimeZone', function() {
    it('should return ms representation of + timezone', function() {
      var ms = ldap2date.getTimeZone('20130228192706.8+531')
      assert.equal(ms, 19860000)
    })

    it('should return ms representation of - timezone', function() {
      var ms = ldap2date.getTimeZone('20130228192706.8-531')
      assert.equal(ms, -19860000)
    })

    it('should return 0 for \'Z\' timezone', function() {
      var ms = ldap2date.getTimeZone('20130228192706.8Z')
      assert.equal(ms, 0)
    })

    it('minutes should be optional', function() {
      var ms = ldap2date.getTimeZone('20130228192706.8+5')
      assert.equal(ms, 18000000)
    })

    it('should not throw an Error if the timezone is not present', function() {
      assert.doesNotThrow(
        function() {
          ldap2date.getTimeZone('20130228192706.85')
        }
      )
    })

    it('should return null if the timezone is not present', function() {
      var ms = ldap2date.getTimeZone('20130228192706.85')
      assert.strictEqual(ms, null)
    })
  })

  describe('parse', function() {
    it('should return a Date object representing the time', function() {
      var date = ldap2date.parse(time)
      assert.ok(date instanceof Date)
      assert.equal(date.valueOf(), 1362079626607)
    })

    it('should parse Generalized Time string that only has required fields', function() {
      var date = ldap2date.parse('2013022819Z')
      assert.equal(date.valueOf(), 1362078000000)
    })

    it('should parse timezones', function() {
      var date = ldap2date.parse('20130228192706.607Z+500')
      assert.equal(date.valueOf(), 1362097626607)
    })

    it('should not throw an Error if the parsed date is invalid', function() {
      assert.doesNotThrow(
        function() {
          ldap2date.parse('A2013022819Z')
        }
      )
    })

    it('should return null if the parsed date is invalid', function() {
      var date = ldap2date.parse('A2013022819Z')
      assert.strictEqual(date, null)
    })
  })

  describe('toGeneralizedTime', function() {
    it('should return a Generalized Time string', function() {
      var date = new Date(1362079626607)
      var time = ldap2date.toGeneralizedTime(date)
      assert.equal(time, '20130228192706.607Z')
    })
    
    it('should handle single digit years', function() {
      var date = new Date(-61941924311001)
      var time = ldap2date.toGeneralizedTime(date)
      assert.equal(time, '00070220135448.999Z')
    })

    it('should not return fraction, if it is 0', function() {
      var date = new Date(1362079626000)
      var time = ldap2date.toGeneralizedTime(date)
      assert.equal(time, '20130228192706Z')
    })
  })
})
