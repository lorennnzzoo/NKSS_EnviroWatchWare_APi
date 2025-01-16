using Models;
using Post = Models.Post;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;

namespace Services
{
    public class OxideService : IOxideService
    {
        private readonly IOxideRepository _oxideRepository;

        public OxideService(IOxideRepository oxideRepository)
        {
            _oxideRepository = oxideRepository;
        }
        public void CreateOxide(Post.Oxide oxide)
        {
            _oxideRepository.Add(oxide);
        }

        public void DeleteOxide(int id)
        {
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
            _oxideRepository.Update(oxide);
        }
    }
}
