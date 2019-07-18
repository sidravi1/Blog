import numpy as np
import scipy as sp

from autograd import numpy as npa
from autograd import scipy as spa
from autograd import jacobian, elementwise_grad

import sympy as s

s.init_printing()

# --- FUNCTIONS --- #
def inv_T(zeta):
    return npa.hstack([zeta[:-1], npa.exp(zeta[-1])])


def get_learing_rate(base_lr, iter_id, s, gk, tau=1, alpha=0.9):
    s = alpha * gk ** 2 + (1 - alpha) * s
    rho = base_lr * (iter_id ** (-1 / 2 + 1e-16)) / (tau + s ** (1 / 2))

    return rho, s


def optimize(model, lr=0.05, max_iters=50000):

    # initialize variables
    mu = model.mu
    omega = model.omega

    ELBO_old = -np.inf
    ELBO = np.inf

    s_mu = np.full_like(mu, -1.0)
    s_sd = np.full_like(mu, -1.0)

    # accumulators for results
    all_ELBOs = []
    all_mus = []
    all_omegas = []

    # loop till converged
    iters = 0

    while ~np.isclose(ELBO, ELBO_old, rtol=1e-08) and (iters < 50000):

        # draw M samples from normal
        eta_m = np.random.normal(size=mu.shape)

        # Get ELBO
        ELBO_old = ELBO
        ELBO = model.get_ELBO(eta_m)
        all_ELBOs.append(ELBO)

        # gradients
        nab_mu = model.nabla_mu(eta_m)
        nab_om = model.nabla_omega(nab_mu, eta_m)

        # Calculate step-size
        if iters == 0:
            s_mu = nab_mu ** 2
            s_sd == nab_om ** 2

        rho_mu, s_mu = get_learing_rate(lr, iters + 1, s_mu, nab_mu, tau=1, alpha=0.9)
        rho_sd, s_sd = get_learing_rate(lr, iters + 1, s_sd, nab_om, tau=1, alpha=0.9)

        # update vars
        all_mus.append(mu)
        all_omegas.append(omega)

        mu = mu + rho_mu * nab_mu
        omega = omega + rho_sd * nab_om
        model.update_params(mu, omega)

        # print
        if not (iters % 1000):
            print(
                """ITER {}: 
                       mu: {}
                       omega: {}
                       ELBO: {}""".format(
                    iters, mu, omega, ELBO.mean()
                )
            )

        iters += 1

    return all_ELBOs, all_mus, all_omegas


# ---------- MODEL CLASS ----------- #


class Linear_model(object):
    def __init__(
        self,
        y,
        x,
        dims=3,
        prior_beta_mu=0,
        prior_beta_sd=10,
        sigma_shape=1,
        sigma_scale=2,
        inv_T=inv_T,
    ):
        self.y = y
        self.x = x
        self.dims = x.shape[1] + 2  # one for intercept, one of sigma
        self.omega = npa.ones(dims)
        self.mu = npa.ones(dims)

        # priors
        self.betas_mu = npa.full(self.dims - 1, prior_beta_mu)
        self.betas_sd = npa.full(self.dims - 1, prior_beta_sd)
        self.sigma_shape = sigma_shape
        self.sigma_scale = sigma_scale

        # inverse tranform function
        self.inv_T = inv_T

    def _repr_latex_(self):
        return r"""$$
              y \sim \mathcal{{N}}(X'\beta, sigma)\\
              X: {}\times{}\\
              \beta: 1\times{} 
              $$
              """.format(
            self.x.shape[0], self.x.shape[1] + 1, self.dims - 1
        )

    def log_p_theta(self, betas, sigma):
        beta_prior = spa.stats.norm.logpdf(betas, self.betas_mu, self.betas_sd).sum()
        sigma_prior = spa.stats.gamma.logpdf(
            sigma / self.sigma_scale, self.sigma_shape
        ) - npa.log(self.sigma_scale)

        return beta_prior + sigma_prior

    def log_p_x_theta(self, theta):
        # likelihood
        betas = theta[:2]
        sigma = theta[2]  # npa.exp(theta[2])
        ones = np.ones((self.x.shape[0], 1))
        x = np.hstack([ones, self.x])
        yhat = x @ betas
        like = spa.stats.norm.logpdf(self.y, yhat, sigma).sum()

        return like + self.log_p_theta(betas, sigma)

    def nabla_mu(self, eta):

        zeta = (eta * self.omega) + self.mu
        theta = self.inv_T(zeta)

        grad_joint = elementwise_grad(self.log_p_x_theta)(theta)
        grad_transform = elementwise_grad(self.inv_T)(zeta)
        grad_log_det = elementwise_grad(self.log_det_jac)(zeta)
        return grad_joint * grad_transform + grad_log_det

    def nabla_omega(self, nabla_mu_val, eta):
        return nabla_mu_val * eta.T * npa.exp(self.omega) + 1

    def log_det_jac(self, zeta):
        a = jacobian(self.inv_T)(zeta)
        b = npa.linalg.det(a)
        return npa.log(b)

    def get_ELBO(self, eta):

        zeta = (eta * self.omega) + self.mu
        theta = self.inv_T(zeta)

        return (
            self.log_p_x_theta(theta).sum()
            + self.log_det_jac(zeta).sum()
            + self.entropy_normal(zeta).sum()
        )

    def entropy_normal(self, vals):

        p = sp.stats.norm(self.mu, np.exp(self.omega)).pdf(vals)
        return -np.log(p)

    def update_params(self, mu, omega):

        self.mu = mu
        self.omega = omega
