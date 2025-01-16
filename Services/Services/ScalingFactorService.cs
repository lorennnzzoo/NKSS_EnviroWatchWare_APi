using Models;
using Post = Models.Post;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;

namespace Services
{
    public class ScalingFactorService : IScalingFactorService
    {
        private readonly IScalingFactorRepository _scalingFactorRepository;
        public ScalingFactorService(IScalingFactorRepository scalingFactorRepository)
        {
            _scalingFactorRepository = scalingFactorRepository;
        }
        public void CreateScalingFactor(Models.Post.ScalingFactor scalingFactor)
        {
            _scalingFactorRepository.Add(scalingFactor);
        }

        public void DeleteScalingFactor(int id)
        {
            _scalingFactorRepository.Delete(id);
        }

        public IEnumerable<Models.ScalingFactor> GetAllScalingFactors()
        {
            return _scalingFactorRepository.GetAll();
        }

        public Models.ScalingFactor GetScalingFactorById(int id)
        {
            return _scalingFactorRepository.GetById(id);
        }

        public void UpdateScalingFactor(Models.ScalingFactor scalingFactor)
        {
            _scalingFactorRepository.Update(scalingFactor);
        }
    }
}
