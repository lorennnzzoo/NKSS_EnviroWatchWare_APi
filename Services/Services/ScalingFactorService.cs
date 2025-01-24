using Models;
using Post = Models.Post;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;
using System.Linq;

namespace Services
{
    public class ScalingFactorService : IScalingFactorService
    {
        private readonly IScalingFactorRepository _scalingFactorRepository;
        private readonly IChannelRepository _channelRepository;
        public ScalingFactorService(IScalingFactorRepository scalingFactorRepository, IChannelRepository channelRepository)
        {
            _scalingFactorRepository = scalingFactorRepository;
            _channelRepository = channelRepository;
        }
        public void CreateScalingFactor(Models.Post.ScalingFactor scalingFactor)
        {
            _scalingFactorRepository.Add(scalingFactor);
        }

        public void DeleteScalingFactor(int id)
        {
            var channelsLinkedToScalingFactor = _channelRepository.GetAll().Where(e => e.ScalingFactorId == id).ToList();
            if (channelsLinkedToScalingFactor.Any())
            {
                throw new Exceptions.ScalingFactorCannotBeDeletedException(string.Join(",", channelsLinkedToScalingFactor.Select(e => e.Name)));
            }
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
