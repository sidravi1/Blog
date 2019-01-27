import numpy as np

class SampleGenerator:
    """ Generate simulated data """

    PROCESSES = ['poisson']

    def __init__(self, process, params, n_state, transition_mat):
      
        if (len(params) != n_state):
            raise ValueError("params count: {} is not equal to n_state: {}".format(len(params), n_state))
        
        if (transition_mat.shape[0] != n_state) or (transition_mat.shape[0] != transition_mat.shape[1]):
            raise ValueError("`transition_mat` is not square or not equal to `n_state`")

        if not np.isclose(transition_mat.sum(axis=1), 1).all():
            raise ValueError("`transition_mat` rows should add to 1")

        if process not in self.PROCESSES:
            raise NotImplementedError("`process` type of {} is not implemented".format(process))
        
        self.process_type = process
        self.process_params = params
        self.n_state = n_state
        self.transition_mat = transition_mat

    def __validate_inputs(self, n_samples, init_state):
        
        if init_state >= self.n_state:
            raise ValueError("`init_state` is greater than `n_state`:{}".format(init_state))

    def __getsample(self, params):

        if self.process_type == 'poisson':
            sample = np.random.poisson(params['lambda'])
        else:
            raise NotImplementedError("Process type not implemented")

        return sample

    def generate_samples(self, n_samples, seed = 42, init_state = 0, transition_distribution = 'uniform'):

        self.__validate_inputs(n_samples, init_state)

        curr_state = init_state
        state_history = []
        all_samples = []

        for sample_id in range(n_samples):
            
            all_samples.append(self.__getsample(self.process_params[curr_state]))
            state_history.append(curr_state)

            # do i switch?
            transition_probs = self.transition_mat[curr_state]
            draw = np.random.uniform()
            highs = transition_probs.cumsum()
            lows = np.roll(highs, shift=1)
            lows[0] = 0
            for i, (low, high) in enumerate(zip(lows, highs)):
                if (draw >= low) and (draw < high):
                    curr_state = i
                    break
        
        return np.array(all_samples), np.array(state_history)



                


