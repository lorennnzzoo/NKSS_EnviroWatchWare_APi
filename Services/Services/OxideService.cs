using Models;
using Post = Models.Post;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;
using System.Linq;

namespace Services
{
    public class OxideService : IOxideService
    {
        private readonly IOxideRepository _oxideRepository;
        private readonly IChannelRepository _channelRepository;

        public OxideService(IOxideRepository oxideRepository, IChannelRepository channelRepository)
        {
            _oxideRepository = oxideRepository;
            _channelRepository = channelRepository;
        }
        public void CreateOxide(Post.Oxide oxide)
        {
            var oxidesWithSameName = GetAllOxides().Where(e=>e.OxideName.ToUpper()==oxide.OxideName.ToUpper());
            if (oxidesWithSameName.Any())
            {
                throw new System.Exception($"Oxide With Name '{oxide.OxideName}' Exists");
            }
            
            _oxideRepository.Add(oxide);
        }

        public void DeleteOxide(int id)
        {
            var channelsLinkedToTheOxide = _channelRepository.GetAll().Where(e => e.OxideId == id).ToList();
            if (channelsLinkedToTheOxide.Any())
            {
                var oxide = _oxideRepository.GetById(id);
                throw new Exceptions.OxideCannotBeDeletedException(oxide.OxideName, string.Join(",", channelsLinkedToTheOxide.Select(e => e.Name)));
            }
            _oxideRepository.Delete(id);
        }

        public IEnumerable<Oxide> GetAllOxides()
        {
            return _oxideRepository.GetAll();
        }

        public Oxide GetOxideById(int id)
        {
            return _oxideRepository.GetById(id);
        }

        public void UpdateOxide(Oxide oxide)
        {
            var oxidesWithSameName = GetAllOxides().Where(e=>e.Id!=oxide.Id).Where(e => e.OxideName.ToUpper() == oxide.OxideName.ToUpper());
            if (oxidesWithSameName.Any())
            {
                throw new System.Exception($"Oxide With Name '{oxide.OxideName}' Exists");
            }
            _oxideRepository.Update(oxide);
        }
    }
}
