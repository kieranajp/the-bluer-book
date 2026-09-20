package metrics

import (
	"github.com/google/uuid"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

var (
	accountProvisions = promauto.NewCounter(prometheus.CounterOpts{
		Name: "bluerbook_account_provisions_total",
		Help: "Total users provisioned on a first sighting of their subject.",
	})

	accountMembershipChanges = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "bluerbook_account_membership_changes_total",
		Help: "Total membership changes by action.",
	}, []string{"action"})

	accountInvitationRefusals = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "bluerbook_account_invitation_refusals_total",
		Help: "Total invitation tokens presented and not honoured, by reason.",
	}, []string{"reason"})

	accountErrors = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "bluerbook_account_errors_total",
		Help: "Total account operation errors by operation.",
	}, []string{"operation"})
)

// AccountProbe implements account.Probe with Prometheus metrics and structured logging.
type AccountProbe struct {
	logger logger.Logger
}

func NewAccountProbe(log logger.Logger) *AccountProbe {
	return &AccountProbe{logger: log}
}

func (p *AccountProbe) UserProvisioned(subject string) {
	accountProvisions.Inc()
	p.logger.Info().Str("probe", "account").Str("subject", subject).Msg("user provisioned")
}

func (p *AccountProbe) MembershipChanged(action string, homeID uuid.UUID) {
	accountMembershipChanges.WithLabelValues(action).Inc()
	p.logger.Info().Str("probe", "account").Str("action", action).Str("home_id", homeID.String()).Msg("membership changed")
}

func (p *AccountProbe) InvitationRefused(reason string) {
	accountInvitationRefusals.WithLabelValues(reason).Inc()
	p.logger.Warn().Str("probe", "account").Str("reason", reason).Msg("invitation refused")
}

func (p *AccountProbe) AccountError(operation string, err error) {
	accountErrors.WithLabelValues(operation).Inc()
	p.logger.Error().Str("probe", "account").Str("operation", operation).Err(err).Msg("account operation failed")
}
