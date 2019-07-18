import numpy as np
from advi import Linear_model, optimize, inv_T


# --- Generate some data ---
mu = -3
sd = 2
n_points = 1000

sd_noise = 2.5
x = np.random.normal(0, 2, n_points)

y = mu * x + np.random.normal(5, sd_noise, n_points)


# --- create a model ---
model = Linear_model(y, x.reshape(-1, 1))

# --- optimize ---
elbo, mu, omega = optimize(model, lr=0.03)
mu_transformed = inv_T(mu[-1])

# --- print last value ---
print(
    """ 
   FINAL VALUES:
      beta0: {:0.2f}
      beta1: {:0.2f}
      sigma: {:0.2f}
   """.format(
        *mu_transformed
    )
)
