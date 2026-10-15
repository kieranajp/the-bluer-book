package logger

import "testing"

func TestNewHonoursLevel(t *testing.T) {
	cases := []struct {
		level     LogLevel
		debug     bool
		info, err bool
	}{
		{LogLevelDebug, true, true, true},
		{LogLevelInfo, false, true, true},
		{LogLevelWarn, false, false, true},
		{LogLevelError, false, false, true},
		{"nonsense", false, true, true},
	}
	for _, tc := range cases {
		l := New(tc.level)
		if got := l.Debug().Enabled(); got != tc.debug {
			t.Errorf("%q: debug enabled = %v, want %v", tc.level, got, tc.debug)
		}
		if got := l.Info().Enabled(); got != tc.info {
			t.Errorf("%q: info enabled = %v, want %v", tc.level, got, tc.info)
		}
		if got := l.Error().Enabled(); got != tc.err {
			t.Errorf("%q: error enabled = %v, want %v", tc.level, got, tc.err)
		}
	}
}
