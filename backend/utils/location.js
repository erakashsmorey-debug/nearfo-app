/**
 * ===== NEARFO LOCATION UTILITIES =====
 * 100% FREE location services using:
 * - Device GPS → lat/long (free, from phone)
 * - Nominatim API → reverse geocoding (free, OpenStreetMap)
 * - No Google Maps API needed = $0 cost
 */

const https = require('https');

// ===== NOMINATIM REVERSE GEOCODING (FREE) =====
// Convert lat/long → city, state, country
// Limit: 1 request/second (enough for profile creation)
async function reverseGeocode(latitude, longitude) {
  return new Promise((resolve, reject) => {
    const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${latitude}&lon=${longitude}&zoom=10&addressdetails=1`;

    const options = {
      headers: {
        'User-Agent': 'Nearfo-App/1.0 (contact@nearfo.com)', // Required by Nominatim
        Accept: 'application/json',
      },
    };

    https
      .get(url, options, (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            const result = JSON.parse(data);

            if (result.error) {
              return resolve({
                city: 'Unknown',
                state: 'Unknown',
                country: 'Unknown',
                displayName: 'Unknown Location',
                pincode: '',
              });
            }

            const address = result.address || {};

            resolve({
              city:
                address.city ||
                address.town ||
                address.village ||
                address.suburb ||
                address.county ||
                'Unknown',
              district: address.state_district || address.county || '',
              state: address.state || 'Unknown',
              country: address.country || 'Unknown',
              countryCode: address.country_code || '',
              pincode: address.postcode || '',
              displayName: result.display_name || '',
            });
          } catch (err) {
            resolve({
              city: 'Unknown',
              state: 'Unknown',
              country: 'Unknown',
              displayName: 'Unknown Location',
              pincode: '',
            });
          }
        });
      })
      .on('error', (err) => {
        // Don't crash if Nominatim is down — return defaults
        resolve({
          city: 'Unknown',
          state: 'Unknown',
          country: 'Unknown',
          displayName: 'Unknown Location',
          pincode: '',
        });
      });
  });
}

// ===== FORWARD GEOCODING (FREE) =====
// Convert city name → lat/long
// Useful for search "show posts near Nagpur"
async function forwardGeocode(query) {
  return new Promise((resolve, reject) => {
    const encoded = encodeURIComponent(query);
    const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encoded}&limit=5&addressdetails=1&countrycodes=in`;

    const options = {
      headers: {
        'User-Agent': 'Nearfo-App/1.0 (contact@nearfo.com)',
        Accept: 'application/json',
      },
    };

    https
      .get(url, options, (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            const results = JSON.parse(data);

            const locations = results.map((r) => ({
              latitude: parseFloat(r.lat),
              longitude: parseFloat(r.lon),
              displayName: r.display_name,
              city:
                r.address?.city ||
                r.address?.town ||
                r.address?.village ||
                '',
              state: r.address?.state || '',
            }));

            resolve(locations);
          } catch (err) {
            resolve([]);
          }
        });
      })
      .on('error', () => resolve([]));
  });
}

// ===== DISTANCE CALCULATOR (Haversine) =====
// Calculate distance between two lat/long points in km
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ===== FORMAT DISTANCE =====
// "2.5 km away" or "150 m away"
function formatDistance(km) {
  if (km < 1) {
    return `${Math.round(km * 1000)} m away`;
  }
  if (km < 10) {
    return `${(Math.round(km * 10) / 10).toFixed(1)} km away`;
  }
  return `${Math.round(km)} km away`;
}

// ===== VALIDATE COORDINATES =====
function isValidCoordinates(lat, lng) {
  return (
    typeof lat === 'number' &&
    typeof lng === 'number' &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180 &&
    lat !== 0 &&
    lng !== 0 // Reject null island
  );
}

module.exports = {
  reverseGeocode,
  forwardGeocode,
  calculateDistance,
  formatDistance,
  isValidCoordinates,
};
