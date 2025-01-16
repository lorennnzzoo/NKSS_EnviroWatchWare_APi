using Models;
using Post = Models.Post;
using System.Collections.Generic;

namespace Repositories.Interfaces
{
    public interface IScalingFactorRepository
    {
        ScalingFactor GetById(int id);
        IEnumerable<ScalingFactor> GetAll();
        void Add(Post.ScalingFactor scalingFactor);
        void Update(ScalingFactor scalingFactor);
        void Delete(int id);
    }
}
